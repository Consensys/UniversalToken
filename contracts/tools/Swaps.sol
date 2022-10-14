// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./ERC1820Client.sol";
import "../interface/ERC1820Implementer.sol";

import "../extensions/userExtensions/IERC1400TokensRecipient.sol";
import "../interface/IERC20HoldableToken.sol";
import "../interface/IHoldableERC1400TokenExtension.sol";

import "../IERC1400.sol";


/**
 * @title Swaps
 * @dev Delivery-Vs-Payment contract for investor-to-investor token trades.
 * @dev Intended usage:
 * The purpose of the contract is to allow secure token transfers/exchanges between 2 stakeholders (called holder1 and holder2).
 * From now on, an operation in the Swaps smart contract (transfer/exchange) is called a trade.
 * Depending on the type of trade, one/multiple token transfers will be executed.
 *
 * The simplified workflow is the following:
 * 1) A trade request is created in the Swaps smart contract, it specifies:
 *  - The token holder(s) involved in the trade
 *  - The trade executer (optional)
 *  - An expiration date
 *  - Details on the first token (address, requested amount, standard)
 *  - Details on the second token (address, requested amount, standard)
 *  - Whether the tokens need to be escrowed in the Swaps contract or not
 *  - The current status of the trade (pending / executed / forced / cancelled)
 * 2) The trade is accepted by both token holders
 * 3) [OPTIONAL] The trade is approved by token controllers (only if requested by tokens controllers)
 * 4) The trade is executed (either by the executer in case the executer is specified, or by anyone)
 *
 * STANDARD-AGNOSTIC:
 * The Swaps smart contract is standard-agnostic, it supports ETH, ERC20, ERC721, ERC1400.
 * The advantage of using an ERC1400 token is to leverages its hook property, thus requiring ONE single
 * transaction (operatorTransferByPartition()) to send tokens to the Swaps smart contract instead of TWO
 * with the ERC20 token standard (approve() + transferFrom()).
 *
 * OFF-CHAIN PAYMENT:
 * The contract can be used as escrow contract while waiting for an off-chain payment.
 * Once payment is received off-chain, the token sender realeases the tokens escrowed in
 * the Swaps contract to deliver them to the recipient.
 *
 * ESCROW VS SWAP MODE:
 * In case escrow mode is selected, tokens need to be escrowed in Swaps smart contract
 * before the trade can occur.
 * In case swap mode is selected, tokens are not escrowed in the Swaps. Instead, the Swaps
 * contract is only allowed to transfer tokens ON BEHALF of their owners. When trade is
 * executed, an atomic token swap occurs.
 *
 * EXPIRATION DATE:
 * The trade can be cancelled by both parties in case expiration date is passed.
 *
 * CLAIMS:
 * The executer has the ability to force or cancel the trade.
 * In case of disagreement/missing payment, both parties can contact the "executer"
 * of the trade to deposit a claim and solve the issue.
 *
 * MARKETPLACE:
 * The contract can be used as a token marketplace. Indeed, when trades are created
 * without specifying the recipient address, anyone can purchase them by sending
 * the requested payment in exchange.
 *
 * PRICE ORACLES:
 * When price oracles are defined, those can define the price at which trades need to be executed.
 * This feature is particularly useful for assets with NAV (net asset value).
 *
 */
contract Swaps is Ownable, ERC1820Client, IERC1400TokensRecipient, ERC1820Implementer {
  string constant internal DELIVERY_VS_PAYMENT = "DeliveryVsPayment";
  string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

  uint256 constant internal SECONDS_IN_MONTH = 86400 * 30;
  uint256 constant internal SECONDS_IN_WEEK = 86400 * 7;

  bytes32 constant internal TRADE_PROPOSAL_FLAG = 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc;
  bytes32 constant internal TRADE_ACCEPTANCE_FLAG = 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd;

  bytes32 constant internal BYPASS_ACTION_FLAG = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

  bytes32 constant internal ALL_PARTITIONS = 0x0000000000000000000000000000000000000000000000000000000000000000;

  enum Standard {OffChain, ETH, ERC20, ERC721, ERC1400}

  enum State {Undefined, Pending, Executed, Forced, Cancelled}

  enum TradeType {Allowance, Hold, Escrow}

  enum Holder {Holder1, Holder2}
    
  string internal constant ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  /**
  @dev Include token events so they can be parsed by Ethereum clients from the settlement transactions.
    */
  // Holdable
  event ExecutedHold(
      address indexed token,
      bytes32 indexed holdId,
      bytes32 lockPreimage,
      address recipient
  );
  // ERC20
  event Transfer(address indexed from, address indexed to, uint256 tokens);
  // ERC1400
  event TransferByPartition(
      bytes32 indexed fromPartition,
      address operator,
      address indexed from,
      address indexed to,
      uint256 value,
      bytes data,
      bytes operatorData
  );
  event CreateNote(
      address indexed owner,
      bytes32 indexed noteHash,
      bytes metadata
  );
  event DestroyNote(address indexed owner, bytes32 indexed noteHash);

  struct UserTradeData {
    address tokenAddress;
    uint256 tokenValue;
    bytes32 tokenId;
    Standard tokenStandard;
    bool accepted;
    bool approved;
    TradeType tradeType;
  }
  
  /**
   * @dev Input data for the requestTrade function
   * @param holder1 Address of the first token holder.
   * @param holder2 Address of the second token holder.
   * @param executer Executer of the trade.
   * @param expirationDate Expiration date of the trade.
   * @param tokenAddress1 Address of the first token smart contract.
   * @param tokenValue1 Amount of tokens to send for the first token.
   * @param tokenId1 ERC721ID/holdId/partition of the first token.
   * @param tokenStandard1 Standard of the first token (ETH | ERC20 | ERC721 | ERC1400).
   * @param tokenAddress2 Address of the second token smart contract.
   * @param tokenValue2 Amount of tokens to send for the second token.
   * @param tokenId2 ERC721ID/holdId/partition of the second token.
   * @param tokenStandard2 Standard of the second token (ETH | ERC20 | ERC721 | ERC1400).
   * @param tradeType Indicates whether or not tokens shall be escrowed in the Swaps contract before the trade.
   */
  struct TradeRequestInput {
    address holder1;
    address holder2;
    address executer; // Set to address(0) if no executer is required for the trade
    uint256 expirationDate;
    address tokenAddress1;
    uint256 tokenValue1;
    bytes32 tokenId1;
    Standard tokenStandard1;
    address tokenAddress2; // Set to address(0) if no token is expected in return (for example in case of an off-chain payment)
    uint256 tokenValue2;
    bytes32 tokenId2;
    Standard tokenStandard2;
    TradeType tradeType1;
    TradeType tradeType2;
    uint256 settlementDate;
  }

  struct Trade {
    address holder1;
    address holder2;
    address executer;
    uint256 expirationDate;
    uint256 settlementDate;
    UserTradeData userTradeData1;
    UserTradeData userTradeData2;
    State state;
  }

  // Index of most recent trade request.
  uint256 internal _index;

  // Mapping from index to trade requests.
  mapping(uint256 => Trade) internal _trades;

  // Mapping from token to price oracles.
  mapping(address => address[]) internal _priceOracles;

  // Mapping from (token, operator) to price oracle status.
  mapping(address => mapping(address => bool)) internal _isPriceOracle;

  // Mapping from (token1, token2) to price ownership.
  mapping(address => mapping(address => bool)) internal _priceOwnership;

  // Mapping from (token1, token2, tokenId1, tokenId2) to price.
  mapping(address => mapping (address => mapping (bytes32 =>  mapping (bytes32 => uint256)))) internal _tokenUnitPricesByPartition;

  // Indicate whether Swaps smart contract is owned or not (for instance by an exchange, etc.).
  bool internal _ownedContract;

  // Array of trade execcuters.
  address[] internal _tradeExecuters;

  // Mapping from operator to trade executer status.
  mapping(address => bool) internal _isTradeExecuter;

  // Mapping from token to token controllers.
  mapping(address => address[]) internal _tokenControllers;

  // Mapping from (token, operator) to token controller status.
  mapping(address => mapping(address => bool)) internal _isTokenController;

  // Mapping from token to variable price start date.
  mapping(address => uint256) internal _variablePriceStartDate;

  /**
   * @dev Modifier to verify if sender is a token controller.
   */
  modifier onlyTokenController(address tokenAddress) {
    require(
      msg.sender == Ownable(tokenAddress).owner() ||
      _isTokenController[tokenAddress][msg.sender],
      "Sender is not a token controller."
    );
    _;
  }

  /**
   * @dev Modifier to verify if sender is a price oracle.
   */
  modifier onlyPriceOracle(address tokenAddress) {
    require(_checkPriceOracle(tokenAddress, msg.sender), "Sender is not a price oracle.");
    _;
  }

  /**
   * [Swaps CONSTRUCTOR]
   * @dev Initialize Swaps + register
   * the contract implementation in ERC1820Registry.
   */
  constructor(bool owned) {
    ERC1820Implementer._setInterface(DELIVERY_VS_PAYMENT);
    ERC1820Implementer._setInterface(ERC1400_TOKENS_RECIPIENT);
    setInterfaceImplementation(ERC1400_TOKENS_RECIPIENT, address(this));

    _ownedContract = owned;

    if(_ownedContract) {
      address[] memory initialTradeExecuters = new address[] (1);
      initialTradeExecuters[0] = msg.sender;
      _setTradeExecuters(initialTradeExecuters);
    }
  }

  /**
   * [ERC1400TokensRecipient INTERFACE (1/2)]
   * @dev Indicate whether or not the Swaps contract can receive the tokens or not. [USED FOR ERC1400 TOKENS ONLY]
   * @param data Information attached to the token transfer.
   * @param operatorData Information attached to the Swaps transfer, by the operator.
   * @return 'true' if the Swaps contract can receive the tokens, 'false' if not.
   */
  function canReceive(bytes calldata, bytes32, address, address, address, uint, bytes calldata  data, bytes calldata operatorData) external override pure returns(bool) {
    return(_canReceive(data, operatorData));
  }

  /**
   * [ERC1400TokensRecipient INTERFACE (2/2)]
   * @dev Hook function executed when tokens are sent to the Swaps contract. [USED FOR ERC1400 TOKENS ONLY]
   * @param partition Name of the partition.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the token transfer.
   * @param operatorData Information attached to the Swaps transfer, by the operator.
   */
  function tokensReceived(bytes calldata, bytes32 partition, address, address from, address to, uint value, bytes memory data, bytes calldata operatorData) external override {
    require(interfaceAddr(msg.sender, "ERC1400Token") == msg.sender, "55"); // funds locked (lockup period)

    require(to == address(this), "50"); // 0x50	transfer failure
    require(_canReceive(data, operatorData), "57"); // 0x57	invalid receiver

    bytes32 flag = _getTradeFlag(data);
    if(flag == TRADE_PROPOSAL_FLAG) {
      address recipient;
      address executor;
      uint256 expirationDate;
      uint256 settlementDate;
      assembly {
        recipient:= mload(add(data, 64))
        executor:= mload(add(data, 96))
        expirationDate:= mload(add(data, 128))
        settlementDate:= mload(add(data, 160))
      }
      // Token data: < 1: address > < 2: amount > < 3: id/partition > < 4: standard > < 5: accepted > < 6: approved >
      UserTradeData memory _tradeData1 = UserTradeData(msg.sender, value, partition, Standard.ERC1400, true, false, TradeType.Escrow);
      UserTradeData memory _tokenData2 = _getTradeTokenData(data);

      _requestTrade(
        from,
        recipient,
        executor,
        expirationDate,
        settlementDate,
        _tradeData1,
        _tokenData2
      );

    } else if (flag == TRADE_ACCEPTANCE_FLAG) {
      uint256 index;
      bytes32 preimage = bytes32(0);
      assembly {
        index:= mload(add(data, 64))
      }
      if (data.length == 96) {
        //This field is optional
        //If the data's length does not include the preimage
        //then return an empty preimage
        //canReceive accepts both data lengths
        assembly {
          preimage:= mload(add(data, 96))
        }
      }
      Trade storage trade = _trades[index];

      UserTradeData memory selectedUserTradeData = (from == trade.holder1) ? trade.userTradeData1 : trade.userTradeData2;
      require(msg.sender == selectedUserTradeData.tokenAddress, "Wrong token sent");
      require(partition == selectedUserTradeData.tokenId, "Tokens of the wrong partition sent");
      require(Standard.ERC1400 == selectedUserTradeData.tokenStandard, "Tokens of the wrong standard sent");

      _acceptTrade(index, from, 0, value, preimage);         
    }
  }

  /**
   * @dev Create a new trade request in the Swaps smart contract.
   * @param inputData The input for this function
   */
  function requestTrade(TradeRequestInput calldata inputData, bytes32 preimage)
    external
    payable
  {
    _requestTrade(
      inputData.holder1,
      inputData.holder2,
      inputData.executer,
      inputData.expirationDate,
      inputData.settlementDate,
      UserTradeData(inputData.tokenAddress1, inputData.tokenValue1, inputData.tokenId1, inputData.tokenStandard1, false, false, inputData.tradeType1),
      UserTradeData(inputData.tokenAddress2, inputData.tokenValue2, inputData.tokenId2, inputData.tokenStandard2, false, false, inputData.tradeType2)
    );

    if(msg.sender == inputData.holder1 || msg.sender == inputData.holder2) {
      _acceptTrade(_index, msg.sender, msg.value, 0, preimage);
    }
  }

  /**
   * @dev Create a new trade request in the Swaps smart contract.
   * @param holder1 Address of the first token holder.
   * @param holder2 Address of the second token holder.
   * @param executer Executer of the trade.
   * @param expirationDate Expiration date of the trade.
   * @param userTradeData1 Encoded pack of variables for token1 (address, amount, id/partition, standard, accepted, approved).
   * @param userTradeData2 Encoded pack of variables for token2 (address, amount, id/partition, standard, accepted, approved).
   */
  function _requestTrade(
    address holder1,
    address holder2,
    address executer, // Set to address(0) if no executer is required for the trade
    uint256 expirationDate,
    uint256 settlementDate,
    UserTradeData memory userTradeData1,
    UserTradeData memory userTradeData2
  ) 
    internal
  {
    if(userTradeData1.tokenStandard == Standard.ETH) {
      require(userTradeData1.tradeType == TradeType.Escrow, "Ether trades need to be of type Escrow");
    }

    if(userTradeData2.tokenStandard == Standard.ETH) {
      require(userTradeData2.tradeType == TradeType.Escrow, "Ether trades need to be of type Escrow");
    }

    if (userTradeData1.tradeType == TradeType.Hold) {
      require(userTradeData1.tokenStandard == Standard.ERC20 || userTradeData1.tokenStandard == Standard.ERC1400, "Invalid token standard for hold trade type");
      require(userTradeData1.tokenId != bytes32(0), "No holdId specified");
    }
    
    if (userTradeData2.tradeType == TradeType.Hold) {
      require(userTradeData2.tokenStandard == Standard.ERC20 || userTradeData2.tokenStandard == Standard.ERC1400, "Invalid token standard for hold trade type");
      require(userTradeData2.tokenId != bytes32(0), "No holdId specified");
    }

    if(_ownedContract) {
      require(_isTradeExecuter[executer], "Trade executer needs to belong to the list of allowed trade executers");
    }

    require(holder1 != address(0), "A trade can not be created with the zero address");
    
    _index++;

    uint256 _expirationDate = (expirationDate > block.timestamp) ? expirationDate : (block.timestamp + SECONDS_IN_MONTH);

    _trades[_index] = Trade({
      holder1: holder1,
      holder2: holder2,
      executer: executer,
      expirationDate: _expirationDate,
      settlementDate: settlementDate,
      userTradeData1: userTradeData1,
      userTradeData2: userTradeData2,
      state: State.Pending
    });
  }

  /**
   * @dev Accept a given trade (+ potentially escrow tokens).
   * @param index Index of the trade to be accepted.
   */
  function acceptTrade(uint256 index, bytes32 preimage) external payable {
    _acceptTrade(index, msg.sender, msg.value, 0, preimage);
  }

  /**
   * @dev Accept a given trade (+ potentially escrow tokens).
   * @param index Index of the trade to be accepted.
   * @param sender Message sender
   * @param ethValue Value sent (only used for ETH)
   * @param erc1400TokenValue Value sent (only used for ERC1400)
   */
  function _acceptTrade(uint256 index, address sender, uint256 ethValue, uint256 erc1400TokenValue, bytes32 preimage) internal {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, "Trade is not pending");

    address recipientHolder;
    if(sender == trade.holder1) {
      recipientHolder = trade.holder2;
    } else if(sender == trade.holder2) {
      recipientHolder = trade.holder1;
    } else if(trade.holder2 == address(0)) {
      trade.holder2 = sender;
      recipientHolder = trade.holder1;
    } else {
      revert("Only registered holders can accept a trade");
    }

    UserTradeData memory selectedUserTradeData = (sender == trade.holder1) ? trade.userTradeData1 : trade.userTradeData2;

    require(!selectedUserTradeData.accepted, "Trade already accepted by the holder");

    if(selectedUserTradeData.tradeType == TradeType.Escrow) {
      if(selectedUserTradeData.tokenStandard == Standard.ETH) {
        require(ethValue == selectedUserTradeData.tokenValue, "Amount of ETH is not correct");
      } else if(selectedUserTradeData.tokenStandard == Standard.ERC20) {        
        IERC20(selectedUserTradeData.tokenAddress).transferFrom(sender, address(this), selectedUserTradeData.tokenValue);
      } else if(selectedUserTradeData.tokenStandard == Standard.ERC721) {
        IERC721(selectedUserTradeData.tokenAddress).transferFrom(sender, address(this), uint256(selectedUserTradeData.tokenId));
      } else if((selectedUserTradeData.tokenStandard == Standard.ERC1400) && erc1400TokenValue == 0){
        IERC1400(selectedUserTradeData.tokenAddress).operatorTransferByPartition(selectedUserTradeData.tokenId, sender, address(this), selectedUserTradeData.tokenValue, abi.encodePacked(BYPASS_ACTION_FLAG), abi.encodePacked(BYPASS_ACTION_FLAG));
      } else if((selectedUserTradeData.tokenStandard == Standard.ERC1400) && erc1400TokenValue != 0){
        require(erc1400TokenValue == selectedUserTradeData.tokenValue, "Amount of ERC1400 tokens is not correct");
      }
    } else if (selectedUserTradeData.tradeType == TradeType.Hold) {
        require(_holdExists(sender, recipientHolder, selectedUserTradeData), "Hold needs to be provided in token smart contract first");
    } else { // trade.tradeType == TradeType.Allowance
        require(_allowanceIsProvided(sender, selectedUserTradeData), "Allowance needs to be provided in token smart contract first");
    }

    if(sender == trade.holder1) {
      trade.userTradeData1.accepted = true;
    } else {
      trade.userTradeData2.accepted = true;
    }

    
    bool settlementDatePassed = block.timestamp >= trade.settlementDate;
    bool tradeApproved = getTradeApprovalStatus(index);
    //Execute both holds of a trade if the following conditions are met
    //* There is no executer set. Only the executer should execute transactions if one is defined
    //* Both trade types are holds
    //* The trade is approved. Token controllers must pre-approve this trade. This is also true if the token has no token controllers
    //* If both holds exist according to _holdExists
    //* If the current block timestamp is after the settlement date
    if (settlementDatePassed && trade.executer == address(0) && trade.userTradeData1.tradeType == TradeType.Hold && trade.userTradeData2.tradeType == TradeType.Hold && tradeApproved) {
      //we know selectedUserTradeData has a hold that exists, so check the other one
      UserTradeData memory otherUserTradeData = (sender == trade.holder1) ? trade.userTradeData2 : trade.userTradeData1;
      if (_holdExists(recipientHolder, sender, otherUserTradeData)) {
        //If both holds exist, then mark both sides of trade as accepted
        //Next if will execute trade
        trade.userTradeData1.accepted = true;
        trade.userTradeData2.accepted = true;
      }
    }

    if(
      trade.executer == address(0) && getTradeAcceptanceStatus(index) && tradeApproved && settlementDatePassed) {
      _executeTrade(index, preimage);
    }
  }
  /**
   * @dev Verify if a trade has been accepted by the token holders.
   *
   * The trade needs to be accepted by both parties (token holders) before it gets executed.
   *
   * @param index Index of the trade to be accepted.
   */
  function getTradeAcceptanceStatus(uint256 index) public view returns(bool) {
    Trade storage trade = _trades[index];

    if(trade.state == State.Pending) {
      if(trade.userTradeData1.tradeType == TradeType.Allowance && !_allowanceIsProvided(trade.holder1, trade.userTradeData1)) {
        return false;
      }
      if(trade.userTradeData2.tradeType == TradeType.Allowance && !_allowanceIsProvided(trade.holder2, trade.userTradeData2)) {
        return false;
      }
    }

    return(trade.userTradeData1.accepted && trade.userTradeData2.accepted);
  }

  /**
   * @dev Verify if a token allowance has been provided in token smart contract.
   *
   * @param sender Address of the sender.
   * @param userTradeData Encoded pack of variables for the token (address, amount, id/partition, standard, accepted, approved).
   */
  function _allowanceIsProvided(address sender, UserTradeData memory userTradeData) internal view returns(bool) {
    address tokenAddress = userTradeData.tokenAddress;
    uint256 tokenValue = userTradeData.tokenValue;
    bytes32 tokenId = userTradeData.tokenId;
    Standard tokenStandard = userTradeData.tokenStandard;

    if(tokenStandard == Standard.ERC20) {        
      return(IERC20(tokenAddress).allowance(sender, address(this)) >= tokenValue);
    } else if(tokenStandard == Standard.ERC721) {
      return(IERC721(tokenAddress).getApproved(uint256(tokenId)) == address(this));
    } else if(tokenStandard == Standard.ERC1400){
      return(IERC1400(tokenAddress).allowanceByPartition(tokenId, sender, address(this)) >= tokenValue);
    }

    return true;
  }

  function approveTrade(uint256 index, bool approved) external {
    approveTradeWithPreimage(index, approved, 0);
  }

  /**
   * @dev Approve a trade (if the tokens involved in the trade are controlled)
   *
   * This function can only be called by a token controller of one of the tokens involved in the trade.
   *
   * Indeed, when a token smart contract is controlled by an owner, the owner can decide to open the
   * secondary market by:
   *  - Allowlisting the Swaps smart contract
   *  - Setting "token controllers" in the Swaps smart contract, in order to approve all the trades made with his token
   *
   * @param index Index of the trade to be executed.
   * @param approved 'true' if trade is approved, 'false' if not.
   */
  function approveTradeWithPreimage(uint256 index, bool approved, bytes32 preimage) public {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, "Trade is not pending");

    require(_isTokenController[trade.userTradeData1.tokenAddress][msg.sender] || _isTokenController[trade.userTradeData2.tokenAddress][msg.sender], "Only token controllers of involved tokens can approve a trade");

    if(_isTokenController[trade.userTradeData1.tokenAddress][msg.sender]) {
      trade.userTradeData1.approved = approved;
    }
    
    if(_isTokenController[trade.userTradeData2.tokenAddress][msg.sender]) {
      trade.userTradeData2.approved = approved;
    }

    if(trade.executer == address(0) && getTradeAcceptanceStatus(index) && getTradeApprovalStatus(index)) {
      _executeTrade(index, preimage);
    }
  }

  /**
   * @dev Verify if a trade has been approved by the token controllers.
   *
   * In case a given token has token controllers, those need to validate the trade before it gets executed.
   *
   * @param index Index of the trade to be approved.
   */
  function getTradeApprovalStatus(uint256 index) public view returns(bool) {
    Trade storage trade = _trades[index];

    if(_tokenControllers[trade.userTradeData1.tokenAddress].length != 0 && !trade.userTradeData1.approved) {
      return false;
    }

    if(_tokenControllers[trade.userTradeData2.tokenAddress].length != 0 && !trade.userTradeData2.approved) {
      return false;
    }

    return true;
  }

  function executeTrade(uint256 index) external {
    executeTradeWithPreimage(index, 0);
  }

  /**
   * @dev Execute a trade in the Swaps contract if possible (e.g. if tokens have been esccrowed, in case it is required).
   *
   * This function can only be called by the executer specified at trade creation.
   * If no executer is specified, the trade can be launched by anyone.
   *
   * @param index Index of the trade to be executed.
   */
  function executeTradeWithPreimage(uint256 index, bytes32 preimage) public {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, "Trade is not pending");

    if(trade.executer != address(0)) {
      require(msg.sender == trade.executer, "Trade can only be executed by executer defined at trade creation");
    }

    require(block.timestamp >= trade.settlementDate, "Trade can only be executed on or after settlement date");

    require(getTradeAcceptanceStatus(index), "Trade has not been accepted by all token holders yet");
    
    require(getTradeApprovalStatus(index), "Trade has not been approved by all token controllers yet");

    _executeTrade(index, preimage);
  }

  /**
   * @dev Execute a trade in the Swaps contract if possible (e.g. if tokens have been esccrowed, in case it is required).
   * @param index Index of the trade to be executed.
   */
  function _executeTrade(uint256 index, bytes32 preimage) internal {
    Trade storage trade = _trades[index];

    uint256 price = getPrice(index);

    uint256 tokenValue1 = trade.userTradeData1.tokenValue;
    uint256 tokenValue2 = trade.userTradeData2.tokenValue;

    if(price == tokenValue2) {
      _transferUsersTokens(index, Holder.Holder1, tokenValue1, false, preimage);
      _transferUsersTokens(index, Holder.Holder2, tokenValue2, false, preimage);
    } else {
      //Holds cannot move a specific amount of tokens
      //So require that if the price is less than the value
      //that the trade is not a hold trade
      require(price <= tokenValue2 && trade.userTradeData2.tradeType != TradeType.Hold, "Price is higher than amount escrowed/authorized");
      _transferUsersTokens(index, Holder.Holder1, tokenValue1, false, preimage);
      _transferUsersTokens(index, Holder.Holder2, price, false, preimage);
      if(trade.userTradeData2.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder2, tokenValue2 - price, true, preimage);
      }
    }
    trade.state = State.Executed;

  }

  function forceTrade(uint256 index) external {
    forceTradeWithPreimage(index, 0);
  }

  /**
   * @dev Force a trade execution in the Swaps contract by transferring tokens back to their target recipients.
   * @param index Index of the trade to be forced.
   */
  function forceTradeWithPreimage(uint256 index, bytes32 preimage) public {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, "Trade is not pending");
    
    address tokenAddress1 = trade.userTradeData1.tokenAddress;
    uint256 tokenValue1 = trade.userTradeData1.tokenValue;
    bool accepted1 = trade.userTradeData1.accepted;

    address tokenAddress2 = trade.userTradeData2.tokenAddress;
    uint256 tokenValue2 = trade.userTradeData2.tokenValue;
    bool accepted2 = trade.userTradeData2.accepted;

    require(!(accepted1 && accepted2), "executeTrade can be called");
    require(_tokenControllers[tokenAddress1].length == 0 && _tokenControllers[tokenAddress2].length == 0, "Trade can not be forced if tokens have controllers");

    if(trade.executer != address(0)) {
      require(msg.sender == trade.executer, "Sender is not allowed to force trade (0)");
    } else if(accepted1) {
      require(msg.sender == trade.holder1, "Sender is not allowed to force trade (1)");
    } else if(accepted2) {
      require(msg.sender == trade.holder2, "Sender is not allowed to force trade (2)");
    } else {
      revert("Trade can't be forced as tokens are not available so far");
    }

    if(accepted1) {
      _transferUsersTokens(index, Holder.Holder1, tokenValue1, false, preimage);
    }

    if(accepted2) {
      _transferUsersTokens(index, Holder.Holder2, tokenValue2, false, preimage);
    }

    trade.state = State.Forced;
  }

  /**
   * @dev Cancel a trade execution in the Swaps contract by transferring tokens back to their initial owners.
   * @param index Index of the trade to be cancelled.
   */
  function cancelTrade(uint256 index) external {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, "Trade is not pending");

    uint256 tokenValue1 = trade.userTradeData1.tokenValue;
    bool accepted1 = trade.userTradeData1.accepted;

    uint256 tokenValue2 = trade.userTradeData2.tokenValue;
    bool accepted2 = trade.userTradeData2.accepted;

    if(accepted1 && accepted2) {
      require(msg.sender == trade.executer || (block.timestamp >= trade.expirationDate && (msg.sender == trade.holder1 || msg.sender == trade.holder2) ), "Sender is not allowed to cancel trade (0)");
      if(trade.userTradeData1.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder1, tokenValue1, true, bytes32(0));
      }
      if(trade.userTradeData2.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder2, tokenValue2, true, bytes32(0));
      }
    } else if(accepted1) {
      require(msg.sender == trade.executer || (block.timestamp >= trade.expirationDate && msg.sender == trade.holder1), "Sender is not allowed to cancel trade (1)");
      if(trade.userTradeData1.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder1, tokenValue1, true, bytes32(0));
      }
    } else if(accepted2) {
      require(msg.sender == trade.executer || (block.timestamp >= trade.expirationDate && msg.sender == trade.holder2), "Sender is not allowed to cancel trade (2)");
      if(trade.userTradeData2.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder2, tokenValue2, true, bytes32(0));
      }
    } else {
      require(msg.sender == trade.executer || msg.sender == trade.holder1 || msg.sender == trade.holder2, "Sender is not allowed to cancel trade (3)");
    }

    trade.state = State.Cancelled;
  }

  function _transferUsersTokens(uint256 index, Holder holder, uint256 value, bool revertTransfer, bytes32 preimage) internal { 
    Trade storage trade = _trades[index];

    UserTradeData memory senderUserTradeData = (holder == Holder.Holder1) ? trade.userTradeData1 : trade.userTradeData2;

    TradeType tokenTradeType = senderUserTradeData.tradeType;

    if (tokenTradeType == TradeType.Hold) {
      _executeHoldOnUsersTokens(index, holder, value, revertTransfer, preimage);
    } else {
      _executeTransferOnUsersTokens(index, holder, value, revertTransfer);
    }
  }

  function _executeHoldOnUsersTokens(uint256 index, Holder holder, uint256, bool, bytes32 preimage) internal { 
    Trade storage trade = _trades[index];

    address sender = (holder == Holder.Holder1) ? trade.holder1 : trade.holder2;
    address recipient = (holder == Holder.Holder1) ? trade.holder2 : trade.holder1;
    UserTradeData memory senderUserTradeData = (holder == Holder.Holder1) ? trade.userTradeData1 : trade.userTradeData2;

    require(block.timestamp <= trade.expirationDate, "Expiration date is past");

    address tokenAddress = senderUserTradeData.tokenAddress;
    bytes32 tokenId = senderUserTradeData.tokenId;
    Standard tokenStandard = senderUserTradeData.tokenStandard;

    require(tokenStandard == Standard.ERC20 || tokenStandard == Standard.ERC1400, "Token standard must be holdable");

    require(_holdExists(sender, recipient, senderUserTradeData), "Hold must exist");

    _executeHold(tokenAddress, tokenId, tokenStandard, preimage, recipient);
  }

  /**
   * @dev Internal function to transfer tokens to their recipient by taking the token standard into account.
   * @param index Index of the trade the token transfer is execcuted for.
   * @param holder Sender of the tokens (currently owning the tokens).
   * @param value Amount of tokens to send.
   * @param revertTransfer If set to true + trade has been accepted, tokens need to be sent back to their initial owners instead of sent to the target recipient.
   */
  function _executeTransferOnUsersTokens(uint256 index, Holder holder, uint256 value, bool revertTransfer) internal {
    Trade storage trade = _trades[index];

    address sender = (holder == Holder.Holder1) ? trade.holder1 : trade.holder2;
    address recipient = (holder == Holder.Holder1) ? trade.holder2 : trade.holder1;
    UserTradeData storage senderUserTradeData = (holder == Holder.Holder1) ? trade.userTradeData1 : trade.userTradeData2;

    address tokenAddress = senderUserTradeData.tokenAddress;
    bytes32 tokenId = senderUserTradeData.tokenId;
    Standard tokenStandard = senderUserTradeData.tokenStandard;

    address currentHolder = sender;
    if(senderUserTradeData.tradeType == TradeType.Escrow) {
      currentHolder = address(this);
    }

    if(revertTransfer) {
      recipient = sender;
    } else {
      require(block.timestamp <= trade.expirationDate, "Expiration date is past");
    }

    if(tokenStandard == Standard.ETH) {
      address payable payableRecipient = payable(recipient);
      payableRecipient.transfer(value);
    } else if(tokenStandard == Standard.ERC20) {
      if(currentHolder == address(this)) {
        IERC20(tokenAddress).transfer(recipient, value);
      } else {
        IERC20(tokenAddress).transferFrom(currentHolder, recipient, value);
      }
    } else if(tokenStandard == Standard.ERC721) {
      IERC721(tokenAddress).transferFrom(currentHolder, recipient, uint256(tokenId));
    } else if(tokenStandard == Standard.ERC1400) {
      IERC1400(tokenAddress).operatorTransferByPartition(tokenId, currentHolder, recipient, value, "", "");
    }

  }

  function _executeHold(
    address token,
    bytes32 tokenHoldId,
    Standard tokenStandard,
    bytes32 preimage,
    address tokenRecipient
  ) internal {
    // Token 1
    if (tokenStandard == Standard.ERC20) {
      require(token != address(0), "token can not be a zero address");

      IERC20HoldableToken(token).executeHold(tokenHoldId, preimage);
    } else if (tokenStandard == Standard.ERC1400) {
      require(token != address(0), "token can not be a zero address");

      address tokenExtension = interfaceAddr(token, ERC1400_TOKENS_VALIDATOR);
      require(
          tokenExtension != address(0),
          "token has no holdable token extension"
      );

      uint256 holdValue;
      (,,,,holdValue,,,,) = IHoldableERC1400TokenExtension(tokenExtension).retrieveHoldData(token, tokenHoldId);

      IHoldableERC1400TokenExtension(tokenExtension).executeHold(
          token,
          tokenHoldId,
          holdValue,
          preimage
      );
    } else {
        revert("invalid token standard");
    }

    emit ExecutedHold(
        token,
        tokenHoldId,
        preimage,
        tokenRecipient
    );
  }

  function _holdExists(address sender, address recipient, UserTradeData memory userTradeData) internal view returns(bool) {
    address tokenAddress = userTradeData.tokenAddress;
    bytes32 holdId = userTradeData.tokenId;
    Standard tokenStandard = userTradeData.tokenStandard;
    
    if(tokenStandard == Standard.ERC1400) {
      address tokenExtension = interfaceAddr(tokenAddress, ERC1400_TOKENS_VALIDATOR);
      require(
          tokenExtension != address(0),
          "token has no holdable token extension"
      );

      HoldStatusCode holdStatus;
      address holdSender;
      address holdRecipient;
      uint256 holdValue;
      address notary;
      bytes32 secretHash;
      (,holdSender,holdRecipient,notary,holdValue,,secretHash,,holdStatus) = IHoldableERC1400TokenExtension(tokenExtension).retrieveHoldData(tokenAddress, holdId);
      return holdStatus == HoldStatusCode.Ordered && holdValue == userTradeData.tokenValue && (holdSender == sender || holdSender == address(0)) && holdRecipient == recipient && (secretHash != bytes32(0) || notary == address(this));
    } else if (tokenStandard == Standard.ERC20) {
      ERC20HoldData memory data = IERC20HoldableToken(tokenAddress).retrieveHoldData(holdId);
      return (data.sender == sender || data.sender == address(0)) && data.recipient == recipient && data.amount == userTradeData.tokenValue && data.status == HoldStatusCode.Ordered && (data.secretHash != bytes32(0) || data.notary == address(this));
    } else {
      revert("Invalid tokenStandard provided");
    }
  }

  /**
   * @dev Indicate whether or not the Swaps contract can receive the tokens or not.
   *
   * By convention, the 32 first bytes of a token transfer to the Swaps smart contract contain a flag.
   *
   *  - When tokens are transferred to Swaps contract to propose a new trade. The 'data' field starts with the
   *  following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *  In this case the data structure is the the following:
   *  <tradeFlag (32 bytes)><recipient address (32 bytes)><executer address (32 bytes)><expiration date (32 bytes)><requested token data (4 * 32 bytes)>
   *
   *  - When tokens are transferred to Swaps contract to accept an existing trade. The 'data' field starts with the
   *  following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *  In this case the data structure is the the following:
   *  <tradeFlag (32 bytes)><request index (32 bytes)>
   *
   * If the 'data' doesn't start with one of those flags, the Swaps contract won't accept the token transfer.
   *
   * @param data Information attached to the Swaps transfer.
   * @param operatorData Information attached to the Swaps transfer, by the operator.
   * @return 'true' if the Swaps contract can receive the tokens, 'false' if not.
   */
  function _canReceive(bytes memory data, bytes memory operatorData) internal pure returns(bool) {
    if(operatorData.length == 0) { // The reason for this check is to avoid a certificate gets interpreted as a flag by mistake
      return false;
    }
    
    bytes32 flag = _getTradeFlag(data);
    if(data.length == 320 && flag == TRADE_PROPOSAL_FLAG) {
      return true;
    } else if ((data.length == 64 || data.length == 96) && flag == TRADE_ACCEPTANCE_FLAG) {
      return true;
    } else if (data.length == 32 && flag == BYPASS_ACTION_FLAG) {
      return true;
    } else {
      return false;
    }
  }

    /**
   * @dev Retrieve the trade flag from the 'data' field.
   *
   * By convention, the 32 first bytes of a token transfer to the Swaps smart contract contain a flag.
   *  - When tokens are transferred to Swaps contract to propose a new trade. The 'data' field starts with the
   *  following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *  - When tokens are transferred to Swaps contract to accept an existing trade. The 'data' field starts with the
   *  following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *
   * @param data Concatenated information about the trade proposal.
   * @return flag Trade flag.
   */
  function _getTradeFlag(bytes memory data) internal pure returns(bytes32 flag) {
    assembly {
      flag:= mload(add(data, 32))
    }
  }

  /**
   * By convention, when tokens are transferred to Swaps contract to propose a new trade, the 'data' of a token transfer has the following structure:
   *  <tradeFlag (32 bytes)><recipient address (32 bytes)><executer address (32 bytes)><expiration date (32 bytes)><requested token data (5 * 32 bytes)>
   *
   * The first 32 bytes are the flag 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *
   * The next 32 bytes contain the trade recipient address (or the zero address if the recipient is not chosen).
   *
   * The next 32 bytes contain the trade executer address (or zero if the executer is not chosen).
   *
   * The next 32 bytes contain the trade expiration date (or zero if the expiration date is not chosen).
   *
   * The next 32 bytes contain the trade requested token address (or the zero address if the recipient is not chosen).
   * The next 32 bytes contain the trade requested token amount.
   * The next 32 bytes contain the trade requested token id/partition (used when token standard is ERC721 or ERC1400).
   * The next 32 bytes contain the trade requested token standard (OffChain, ERC20, ERC721, ERC1400, ETH).
   * The next 32 bytes contain a boolean precising wether trade has been accepted by token holder or not.
   * The next 32 bytes contain a boolean precising wether trade has been approved by token controller or not.
   *
   * Example input for recipient address '0xb5747835141b46f7C472393B31F8F5A57F74A44f', expiration date '1576348418',
   * trade executer address '0x32F54098916ceb5f57a117dA9554175Fe25611bA', requested token address '0xC6F0410A667a5BEA528d6bc9efBe10270089Bb11',
   * requested token amount '5', requested token id/partition '37252', and requested token type 'ERC1400', accepted and approved:
   * 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000b5747835141b46f7C472393B31F8F5A57F74A44f
   * 000000000000000000000000000000000000000000000000000000157634841800000000000000000000000032F54098916ceb5f57a117dA9554175Fe25611bA
   * 000000000000000000000000C6F0410A667a5BEA528d6bc9efBe10270089Bb110000000000000000000000000000000000000000000000000000000000000005
   * 000000000000000000000000000000000000000000000000000000000037252000000000000000000000000000000000000000000000000000000000000002
   * 000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001
   */

  /**
   * @dev Retrieve the tokenData from the 'data' field.
   *
   * @param data Concatenated information about the trade proposal.
   * @return tokenData Trade token data < 1: address > < 2: amount > < 3: id/partition > < 4: standard > < 5: accepted > < 6: approved >.
   */
  function _getTradeTokenData(bytes memory data) internal pure returns(UserTradeData memory tokenData) {
    address tokenAddress;
    uint256 tokenAmount;
    bytes32 tokenId;
    Standard tokenStandard;
    TradeType tradeType;
    assembly {
      tokenAddress:= mload(add(data, 192))
      tokenAmount:= mload(add(data, 224))
      tokenId:= mload(add(data, 256))
      tokenStandard:= mload(add(data, 288))
      tradeType:= mload(add(data, 320))
    }
    tokenData = UserTradeData(
      tokenAddress,
      tokenAmount,
      tokenId,
      tokenStandard,
      false,
      false,
      tradeType
    );
  }

  /**
   * @dev Retrieve the trade index from the 'data' field.
   *
   * By convention, when tokens are transferred to Swaps contract to accept an existing trade, the 'data' of a token transfer has the following structure:
   *  <tradeFlag (32 bytes)><index uint256 (32 bytes)>
   *
   * The first 32 bytes are the flag 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *
   * The next 32 bytes contain the trade index.
   *
   * Example input for trade index #2985:
   * 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000002985
   *
   * @param data Concatenated information about the trade validation.
   * @return index Trade index.
   */

  /**************************** TRADE EXECUTERS *******************************/

  /**
   * @dev Renounce ownership of the contract.
   */
  function renounceOwnership() public override onlyOwner {
    Ownable.renounceOwnership();
    _ownedContract = false;
  }

  /**
   * @dev Get the list of trade executers as defined by the Swaps contract.
   * @return List of addresses of all the trade executers.
   */
  function tradeExecuters() external view returns (address[] memory) {
    return _tradeExecuters;
  }

  /**
   * @dev Set list of trade executers for the Swaps contract.
   * @param operators Trade executers addresses.
   */
  function setTradeExecuters(address[] calldata operators) external onlyOwner {
    require(_ownedContract, "Swaps contract is not owned");
    _setTradeExecuters(operators);
  }

  /**
   * @dev Set list of trade executers for the Swaps contract.
   * @param operators Trade executers addresses.
   */
  function _setTradeExecuters(address[] memory operators) internal {

    for (uint i = 0; i<_tradeExecuters.length; i++){
      _isTradeExecuter[_tradeExecuters[i]] = false;
    }
    for (uint j = 0; j<operators.length; j++){
      _isTradeExecuter[operators[j]] = true;
    }
    _tradeExecuters = operators;
  }

  /************************** TOKEN CONTROLLERS *******************************/

  /**
   * @dev Get the list of token controllers for a given token.
   * @param tokenAddress Token address.
   * @return List of addresses of all the token controllers for a given token.
   */
  function tokenControllers(address tokenAddress) external view returns (address[] memory) {
    return _tokenControllers[tokenAddress];
  }

  /**
   * @dev Set list of token controllers for a given token.
   * @param tokenAddress Token address.
   * @param operators Operators addresses.
   */
  function setTokenControllers(address tokenAddress, address[] calldata operators) external onlyTokenController(tokenAddress) {
    for (uint i = 0; i<_tokenControllers[tokenAddress].length; i++){
      _isTokenController[tokenAddress][_tokenControllers[tokenAddress][i]] = false;
    }
    for (uint j = 0; j<operators.length; j++){
      _isTokenController[tokenAddress][operators[j]] = true;
    }
    _tokenControllers[tokenAddress] = operators;
  }

  /************************** TOKEN PRICE ORACLES *******************************/

  /**
   * @dev Get the list of price oracles for a given token.
   * @param tokenAddress Token address.
   * @return List of addresses of all the price oracles for a given token.
   */
  function priceOracles(address tokenAddress) external view returns (address[] memory) {
    return _priceOracles[tokenAddress];
  }

  /**
   * @dev Set list of price oracles for a given token.
   * @param tokenAddress Token address.
   * @param oracles Oracles addresses.
   */
  function setPriceOracles(address tokenAddress, address[] calldata oracles) external onlyPriceOracle(tokenAddress) {
    for (uint i = 0; i<_priceOracles[tokenAddress].length; i++){
      _isPriceOracle[tokenAddress][_priceOracles[tokenAddress][i]] = false;
    }
    for (uint j = 0; j<oracles.length; j++){
      _isPriceOracle[tokenAddress][oracles[j]] = true;
    }
    _priceOracles[tokenAddress] = oracles;
  }

  /**
   * @dev Check if address is oracle of a given token.
   * @param tokenAddress Token address.
   * @param oracle Oracle address.
   * @return 'true' if the address is oracle of the given token.
   */
  function _checkPriceOracle(address tokenAddress, address oracle) internal view returns(bool) {
    return(_isPriceOracle[tokenAddress][oracle] || oracle == Ownable(tokenAddress).owner());
  }

  /****************************** Swaps PRICES *********************************/

  /**
   * @dev Get price of the token.
   * @param tokenAddress1 Address of the token to be priced.
   * @param tokenAddress2 Address of the token to pay for token1.
   */
  function getPriceOwnership(address tokenAddress1, address tokenAddress2) external view returns(bool) {
    return _priceOwnership[tokenAddress1][tokenAddress2];
  }

  /**
   * @dev Take ownership for setting the price of a token.
   * @param tokenAddress1 Address of the token to be priced.
   * @param tokenAddress2 Address of the token to pay for token1.
   */
  function setPriceOwnership(address tokenAddress1, address tokenAddress2, bool priceOwnership) external onlyPriceOracle(tokenAddress1) {
    _priceOwnership[tokenAddress1][tokenAddress2] = priceOwnership;
  }

  /**
   * @dev Get date after which the token price can potentially be set by an oracle (0 if price can not be set by an oracle).
   * @param tokenAddress Token address.
   */
  function variablePriceStartDate(address tokenAddress) external view returns(uint256) {
    return _variablePriceStartDate[tokenAddress];
  }

  /**
   * @dev Set date after which the token price can potentially be set by an oracle (0 if price can not be set by an oracle).
   * @param tokenAddress Token address.
   * @param startDate Date after which token price can potentially be set by an oracle (0 if price can not be set by an oracle).
   */
  function setVariablePriceStartDate(address tokenAddress, uint256 startDate) external onlyPriceOracle(tokenAddress) {
    require((startDate > block.timestamp + SECONDS_IN_WEEK) || startDate == 0, "Start date needs to be set at least a week before");
    _variablePriceStartDate[tokenAddress] = startDate;
  }

  /**
   * @dev Get price of the token.
   * @param tokenAddress1 Address of the token to be priced.
   * @param tokenAddress2 Address of the token to pay for token1.
   * @param tokenId1 ID/partition of the token1 (set to 0 bytes32 if price is set for all IDs/partitions).
   * @param tokenId1 ID/partition of the token2 (set to 0 bytes32 if price is set for all IDs/partitions).
   */
  function getTokenPrice(address tokenAddress1, address tokenAddress2, bytes32 tokenId1, bytes32 tokenId2) external view returns(uint256) {
    return _tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2];
  }

  /**
   * @dev Set price of a token.
   * @param tokenAddress1 Address of the token to be priced.
   * @param tokenAddress2 Address of the token to pay for token1.
   * @param tokenId1 ID/partition of the token1 (set to 0 bytes32 if price is set for all IDs/partitions).
   * @param tokenId2 ID/partition of the token2 (set to 0 bytes32 if price is set for all IDs/partitions).
   * @param newPrice New price of the token.
   */
  function setTokenPrice(address tokenAddress1, address tokenAddress2, bytes32 tokenId1, bytes32 tokenId2, uint256 newPrice) external {
    require(!(_priceOwnership[tokenAddress1][tokenAddress2] && _priceOwnership[tokenAddress2][tokenAddress1]), "Competition on price ownership");

    if(_priceOwnership[tokenAddress1][tokenAddress2]) {
      require(_checkPriceOracle(tokenAddress1, msg.sender), "Price setter is not an oracle for this token (1)");
    } else if(_priceOwnership[tokenAddress2][tokenAddress1]) {
      require(_checkPriceOracle(tokenAddress2, msg.sender), "Price setter is not an oracle for this token (2)");
    } else {
      revert("No price ownership");
    }

    _tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2] = newPrice;
  }

  /**
   * @dev Get amount of token2 to pay to acquire the token1.
   * @param index Index of the Swaps request.
   */
  function getPrice(uint256 index) public view returns(uint256) {
    Trade storage trade = _trades[index];

    address tokenAddress1 = trade.userTradeData1.tokenAddress;
    uint256 tokenValue1 = trade.userTradeData1.tokenValue;
    bytes32 tokenId1 = trade.userTradeData1.tokenId;

    address tokenAddress2 = trade.userTradeData2.tokenAddress;
    uint256 tokenValue2 = trade.userTradeData2.tokenValue;
    bytes32 tokenId2 = trade.userTradeData2.tokenId;

    require(!(_priceOwnership[tokenAddress1][tokenAddress2] && _priceOwnership[tokenAddress2][tokenAddress1]), "Competition on price ownership");

    if(_variablePriceStartDate[tokenAddress1] == 0 || block.timestamp < _variablePriceStartDate[tokenAddress1]) {
      return tokenValue2;
    }

    if(_priceOwnership[tokenAddress1][tokenAddress2] || _priceOwnership[tokenAddress2][tokenAddress1]) {

      if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2] != 0) {
        return tokenValue1 * (_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][tokenId1] != 0) {
        return tokenValue1 / (_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][tokenId1]);

      } else if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][ALL_PARTITIONS] != 0) {
        return tokenValue1 * (_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][ALL_PARTITIONS]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][tokenId1] != 0) {
        return tokenValue1 / (_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][tokenId1]);

      } else if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][tokenId2] != 0) {
        return tokenValue1 * (_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][tokenId2]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][ALL_PARTITIONS] != 0) {
        return tokenValue1 / (_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][ALL_PARTITIONS]);

      } else if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][ALL_PARTITIONS] != 0) {
        return tokenValue1 * (_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][ALL_PARTITIONS]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][ALL_PARTITIONS] != 0) {
        return tokenValue1 / (_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][ALL_PARTITIONS]);

      } else {
        return tokenValue2;
      }

    } else {
      return tokenValue2;
    }
  }

  /**************************** VIEW FUNCTIONS *******************************/

  /**
   * @dev Get the trade.
   * @param index Index of the trade.
   * @return Trade.
   */
  function getTrade(uint256 index) external view returns(Trade memory) {
    Trade storage trade = _trades[index];
    return trade;
  }

  /**
   * @dev Get the total number of requests in the Swaps contract.
   * @return Total number of requests in the Swaps contract.
   */
  function getNbTrades() external view returns(uint256) {
    return _index;
  }
 }
