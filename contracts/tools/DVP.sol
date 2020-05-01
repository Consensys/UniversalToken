pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "../token/ERC1820/ERC1820Implementer.sol";
import "../token/ERC1400Raw/IERC1400TokensRecipient.sol";
import "../ERC1400.sol";

/**
 * @title DVP
 * @dev Delivery-Vs-Payment contract for investor-to-investor token trades.
 * @dev Intended usage:
 * The purpose of the contract is to allow secure token transfers/exchanges between 2 stakeholders (called holder1 and holder2).
 * From now on, an operation in the DVP smart contract (transfer/exchange) is called a trade.
 * Depending on the type of trade, one/multiple token transfers will be executed.
 *
 * The simplified workflow is the following:
 * 1) A trade request is created in the DVP smart contract, it specifies:
 *  - The token holder(s) involved in the trade
 *  - The trade executer (optional)
 *  - An expiration date
 *  - Details on the first token (address, requested amount, standard)
 *  - Details on the second token (address, requested amount, standard)
 *  - Whether the tokens need to be escrowed in the DVP contract or not
 *  - The current status of the trade (pending / executed / forced / cancelled)
 * 2) The trade is accepted by both token holders
 * 3) [OPTIONAL] The trade is approved by token controllers (only if requested by tokens controllers)
 * 4) The trade is executed (either by the executer in case the executer is specified, or by anyone)
 *
 * STANDARD-AGNOSTIC:
 * The DVP smart contract is standard-agnostic, it supports ETH, ERC20, ERC721, ERC1400.
 * The advantage of using an ERC1400 token is to leverages its hook property, thus requiring ONE single
 * transaction (operatorTransferByPartition()) to send tokens to the DVP smart contract instead of TWO
 * with the ERC20 token standard (approve() + transferFrom()).
 *
 * OFF-CHAIN PAYMENT:
 * The contract can be used as escrow contract while waiting for an off-chain payment.
 * Once payment is received off-chain, the token sender realeases the tokens escrowed in
 * the DVP contract to deliver them to the recipient.
 *
 * ESCROW VS SWAP MODE:
 * In case escrow mode is selected, tokens need to be escrowed in DVP smart contract
 * before the trade can occur.
 * In case swap mode is selected, tokens are not escrowed in the DVP. Instead, the DVP
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
contract DVP is Ownable, ERC1820Client, IERC1400TokensRecipient, ERC1820Implementer {
  using SafeMath for uint256;

  string constant internal DELIVERY_VS_PAYMENT = "DeliveryVsPayment";
  string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

  uint256 constant internal SECONDS_IN_MONTH = 86400 * 30;
  uint256 constant internal SECONDS_IN_WEEK = 86400 * 7;

  bytes32 constant internal ERC1820_ACCEPT_MAGIC = keccak256(abi.encodePacked("ERC1820_ACCEPT_MAGIC"));

  bytes32 constant internal TRADE_PROPOSAL_FLAG = 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc;
  bytes32 constant internal TRADE_ACCEPTANCE_FLAG = 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd;

  bytes32 constant internal BYPASS_ACTION_FLAG = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

  bytes32 constant internal ALL_PARTITIONS = 0x0000000000000000000000000000000000000000000000000000000000000000;

  enum Standard {OffChain, ETH, ERC20, ERC721, ERC1400}

  enum State {Undefined, Pending, Executed, Forced, Cancelled}

  enum TradeType {Escrow, Swap}

  enum Holder {Holder1, Holder2}

  struct Trade {
    address holder1;
    address holder2;
    address executer;
    uint256 expirationDate;
    bytes tokenData1;
    bytes tokenData2;
    TradeType tradeType;
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

  // Indicate whether DVP smart contract allows escrow or not.
  bool internal _isEscrowForbidden;

  // Indicate whether DVP smart contract is owned or not (for instance by an exchange, etc.).
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
   * [DVP CONSTRUCTOR]
   * @dev Initialize DVP + register
   * the contract implementation in ERC1820Registry.
   */
  constructor(bool owned, bool escrowForbidden) public {
    ERC1820Implementer._setInterface(DELIVERY_VS_PAYMENT);
    ERC1820Implementer._setInterface(ERC1400_TOKENS_RECIPIENT);
    setInterfaceImplementation(ERC1400_TOKENS_RECIPIENT, address(this));

    _ownedContract = owned;
    _isEscrowForbidden = escrowForbidden;

    if(_ownedContract) {
      address[] memory initialTradeExecuters = new address[] (1);
      initialTradeExecuters[0] = msg.sender;
      _setTradeExecuters(initialTradeExecuters);
    }
  }

  /**
   * [ERC1400TokensRecipient INTERFACE (1/2)]
   * @dev Indicate whether or not the DVP contract can receive the tokens or not. [USED FOR ERC1400 TOKENS ONLY]
   * @param data Information attached to the token transfer.
   * @param operatorData Information attached to the DVP transfer, by the operator.
   * @return 'true' if the DVP contract can receive the tokens, 'false' if not.
   */
  function canReceive(bytes4, bytes32, address, address, address, uint, bytes calldata  data, bytes calldata operatorData) external view returns(bool) {
    return(_canReceive(data, operatorData));
  }

  /**
   * [ERC1400TokensRecipient INTERFACE (2/2)]
   * @dev Hook function executed when tokens are sent to the DVP contract. [USED FOR ERC1400 TOKENS ONLY]
   * @param partition Name of the partition.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the token transfer.
   * @param operatorData Information attached to the DVP transfer, by the operator.
   */
  function tokensReceived(bytes4, bytes32 partition, address, address from, address to, uint value, bytes calldata data, bytes calldata operatorData) external {
    require(interfaceAddr(msg.sender, "ERC1400Token") == msg.sender, "A8: Transfer Blocked - Token restriction");

    require(to == address(this), "A8: Transfer Blocked - Token restriction");
    require(_canReceive(data, operatorData), "A6: Transfer Blocked - Receiver not eligible");

    bytes32 flag = _getTradeFlag(data);
    if(flag == TRADE_PROPOSAL_FLAG) {
      address _recipient = _getTradeRecipient(data);
      address _executer = _getTradeExecuter(data);
      uint256 _expirationDate = _getTradeExpirationDate(data);

      // Token data: < 1: address > < 2: amount > < 3: id/partition > < 4: standard > < 5: accepted > < 6: approved >
      bytes memory _tokenData1 = abi.encode(msg.sender, value, partition, Standard.ERC1400, true, false);
      bytes memory _tokenData2 = _getTradeTokenData(data);

      _requestTrade(
        from,
        _recipient,
        _executer,
        _expirationDate,
        _tokenData1,
        _tokenData2,
        TradeType.Escrow  
      );

    } else if (flag == TRADE_ACCEPTANCE_FLAG) {
      uint256 index = _getTradeIndex(data);
      Trade storage trade = _trades[index];

      bytes memory selectedTokenData = (from == trade.holder1) ? trade.tokenData1 : trade.tokenData2;
      (address tokenAddress,,,,,) = abi.decode(selectedTokenData, (address, uint256, bytes32, Standard, bool, bool));
      require(msg.sender == tokenAddress, 'Wrong token sent');

      (,, bytes32 tokenId,,,) = abi.decode(selectedTokenData, (address, uint256, bytes32, Standard, bool, bool));
      require(partition == tokenId, 'Tokens of the wrong partition sent');

      (,,, Standard tokenStandard,,) = abi.decode(selectedTokenData, (address, uint256, bytes32, Standard, bool, bool));
      require(Standard.ERC1400 == tokenStandard, 'Tokens of the wrong standard sent');

      _acceptTrade(index, from, 0, value);         
    }
  }

  /**
   * @dev Create a new trade request in the DVP smart contract.
   * @param holder1 Address of the first token holder.
   * @param holder2 Address of the second token holder.
   * @param executer Executer of the trade.
   * @param expirationDate Expiration date of the trade.
   * @param tokenAddress1 Address of the first token smart contract.
   * @param tokenValue1 Amount of tokens to send for the first token.
   * @param tokenId1 ID/partition of the first token.
   * @param tokenStandard1 Standard of the first token (ETH | ERC20 | ERC721 | ERC1400).
   * @param tokenAddress2 Address of the second token smart contract.
   * @param tokenValue2 Amount of tokens to send for the second token.
   * @param tokenId2 ID/partition of the second token.
   * @param tokenStandard2 Standard of the second token (ETH | ERC20 | ERC721 | ERC1400).
   * @param tradeType Indicates whether or not tokens shall be escrowed in the DVP contract before the trade.
   */
  function requestTrade(
    address holder1,
    address holder2,
    address executer, // Set to address(0) if no executer is required for the trade
    uint256 expirationDate,
    address tokenAddress1,
    uint256 tokenValue1,
    bytes32 tokenId1,
    Standard tokenStandard1,
    address tokenAddress2, // Set to address(0) if no token is expected in return (for example in case of an off-chain payment)
    uint256 tokenValue2,
    bytes32 tokenId2,
    Standard tokenStandard2,
    TradeType tradeType
  )
    external
    payable
  {
    // Token data: < 1: address > < 2: amount > < 3: id/partition > < 4: standard > < 5: accepted > < 6: approved >
    bytes memory _tokenData1 = abi.encode(tokenAddress1, tokenValue1, tokenId1, tokenStandard1, false, false);
    bytes memory _tokenData2 = abi.encode(tokenAddress2, tokenValue2, tokenId2, tokenStandard2, false, false);

    _requestTrade(
      holder1,
      holder2,
      executer,
      expirationDate,
      _tokenData1,
      _tokenData2,
      tradeType
    );

    if(msg.sender == holder1 || msg.sender == holder2) {
      _acceptTrade(_index, msg.sender, msg.value, 0);
    }
    
  }

  /**
   * @dev Create a new trade request in the DVP smart contract.
   * @param holder1 Address of the first token holder.
   * @param holder2 Address of the second token holder.
   * @param executer Executer of the trade.
   * @param expirationDate Expiration date of the trade.
   * @param tokenData1 Encoded pack of variables for token1 (address, amount, id/partition, standard, accepted, approved).
   * @param tokenData2 Encoded pack of variables for token2 (address, amount, id/partition, standard, accepted, approved).
   * @param tradeType Indicates whether or not tokens shall be escrowed in the DVP contract before the trade.
   */
  function _requestTrade(
    address holder1,
    address holder2,
    address executer, // Set to address(0) if no executer is required for the trade
    uint256 expirationDate,
    bytes memory tokenData1,
    bytes memory tokenData2,
    TradeType tradeType
  ) 
    internal
  {
    (,,,Standard standard1,,) = abi.decode(tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (,,,Standard standard2,,) = abi.decode(tokenData2, (address, uint256, bytes32, Standard, bool, bool));
    if(standard1 == Standard.ETH || standard2 == Standard.ETH) {
      require(tradeType == TradeType.Escrow, "Ether trades need to be of type Escrow");
    }

    if(_ownedContract) {
      require(_isTradeExecuter[executer], "Trade executer needs to belong to the list of allowed trade executers");
    }

    if(_isEscrowForbidden) {
      require(tradeType != TradeType.Escrow, "This DVP contract doesn't allow Escrows");
    }

    require(holder1 != address(0), "A trade can not be created with the zero address");
    
    _index++;

    uint256 _expirationDate = (expirationDate > block.timestamp) ? expirationDate : (block.timestamp + SECONDS_IN_MONTH);

    _trades[_index] = Trade({
      holder1: holder1,
      holder2: holder2,
      executer: executer,
      expirationDate: _expirationDate,
      tokenData1: tokenData1,
      tokenData2: tokenData2,
      tradeType: tradeType,
      state: State.Pending
    });
  }

  /**
   * @dev Accept a given trade (+ potentially escrow tokens).
   * @param index Index of the trade to be accepted.
   */
  function acceptTrade(uint256 index) external payable {
    _acceptTrade(index, msg.sender, msg.value, 0);
  }

  /**
   * @dev Accept a given trade (+ potentially escrow tokens).
   * @param index Index of the trade to be accepted.
   * @param sender Message sender
   * @param ethValue Value sent (only used for ETH)
   * @param erc1400TokenValue Value sent (only used for ERC1400)
   */
  function _acceptTrade(uint256 index, address sender, uint256 ethValue, uint256 erc1400TokenValue) internal {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, 'Trade is not pending');

    address selectedHolder;
    if(sender == trade.holder1) {
      selectedHolder = trade.holder1;
    } else if(sender == trade.holder2) {
      selectedHolder = trade.holder2;
    } else if(trade.holder2 == address(0)) {
      trade.holder2 = sender;
      selectedHolder = trade.holder2;
    } else {
      revert("Only registered holders can accept a trade");
    }

    bytes memory selectedTokenData = (selectedHolder == trade.holder1) ? trade.tokenData1 : trade.tokenData2;

    (address tokenAddress, uint256 tokenValue, bytes32 tokenId, Standard tokenStandard, bool accepted, bool approved) = abi.decode(selectedTokenData, (address, uint256, bytes32, Standard, bool, bool));
    require(!accepted, "Trade already accepted by the holder");

    if(trade.tradeType == TradeType.Escrow) {
      if(tokenStandard == Standard.ETH) {
        require(ethValue == tokenValue, "Amount of ETH is not correct");
      } else if(tokenStandard == Standard.ERC20) {        
        ERC20(tokenAddress).transferFrom(sender, address(this), tokenValue);
      } else if(tokenStandard == Standard.ERC721) {
        ERC721(tokenAddress).transferFrom(sender, address(this), uint256(tokenId));
      } else if(tokenStandard == Standard.ERC1400 && erc1400TokenValue == 0){
        ERC1400(tokenAddress).operatorTransferByPartition(tokenId, sender, address(this), tokenValue, abi.encodePacked(BYPASS_ACTION_FLAG), abi.encodePacked(BYPASS_ACTION_FLAG));
      } else if(tokenStandard == Standard.ERC1400 && erc1400TokenValue != 0){
        require(erc1400TokenValue == tokenValue, "Amount of ERC1400 tokens is not correct");
      } else {
        // OffChain
      }
    } else { // trade.tradeType == TradeType.Swap
      require(_allowanceIsProvided(sender, selectedTokenData), 'Allowance needs to be provided in token smart contract first');
    }

    bytes memory newTokenData = abi.encode(tokenAddress, tokenValue, tokenId, tokenStandard, true, approved);
    if(selectedHolder == trade.holder1) {
      trade.tokenData1 = newTokenData;
    } else {
      trade.tokenData2= newTokenData;
    }

    if(
      trade.executer == address(0) && _tradeisAccepted(index) && _tradeisApproved(index)) {
      _executeTrade(index);
    }
  }

  /**
   * @dev Verify if a trade has been accepted by the token holders.
   *
   * The trade needs to be accepted by both parties (token holders) before it gets executed.
   *
   * @param index Index of the trade to be accepted.
   */
  function _tradeisAccepted(uint256 index) internal view returns(bool) {
    Trade storage trade = _trades[index];

    (,,,, bool accepted1,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (,,,, bool accepted2,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));

    if(trade.tradeType == TradeType.Swap && trade.state == State.Pending) {
      if(!_allowanceIsProvided(trade.holder1, trade.tokenData1)) {
        return false;
      }
      if(!_allowanceIsProvided(trade.holder2, trade.tokenData2)) {
        return false;
      }
    }

    return(accepted1 && accepted2);
  }

  /**
   * @dev Verify if a token allowance has been provided in token smart contract.
   *
   * @param sender Address of the sender.
   * @param tokenData Encoded pack of variables for the token (address, amount, id/partition, standard, accepted, approved).
   */
  function _allowanceIsProvided(address sender, bytes memory tokenData) internal view returns(bool) {

    (address tokenAddress, uint256 tokenValue, bytes32 tokenId, Standard tokenStandard,,) = abi.decode(tokenData, (address, uint256, bytes32, Standard, bool, bool));
    if(tokenStandard == Standard.ERC20) {        
      return(ERC20(tokenAddress).allowance(sender, address(this)) >= tokenValue);
    } else if(tokenStandard == Standard.ERC721) {
      return(ERC721(tokenAddress).getApproved(uint256(tokenId)) == address(this));
    } else if(tokenStandard == Standard.ERC1400){
      return(ERC1400(tokenAddress).allowanceByPartition(tokenId, sender, address(this)) >= tokenValue);
    }

    return true;
  }

  /**
   * @dev Approve a trade (if the tokens involved in the trade are controlled)
   *
   * This function can only be called by a token controller of one of the tokens involved in the trade.
   *
   * Indeed, when a token smart contract is controlled by an owner, the owner can decide to open the
   * secondary market by:
   *  - Whitelisting the DVP smart contract
   *  - Setting "token controllers" in the DVP smart contract, in order to approve all the trades made with his token
   *
   * @param index Index of the trade to be executed.
   * @param approved 'true' if trade is approved, 'false' if not.
   */
  function approveTrade(uint256 index, bool approved) external {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, 'Trade is not pending');

    (address tokenAddress1,,,,,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (address tokenAddress2,,,,,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));

    require(_isTokenController[tokenAddress1][msg.sender] || _isTokenController[tokenAddress2][msg.sender], "Only token controllers of involved tokens can approve a trade");

    if(_isTokenController[tokenAddress1][msg.sender]) {
      (, uint256 tokenValue1, bytes32 tokenId1, Standard tokenStandard1, bool accepted1,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
      trade.tokenData1 = abi.encode(tokenAddress1, tokenValue1, tokenId1, tokenStandard1, accepted1, approved);
    }
    
    if(_isTokenController[tokenAddress2][msg.sender]) {
      (, uint256 tokenValue2, bytes32 tokenId2, Standard tokenStandard2, bool accepted2,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));
      trade.tokenData2 = abi.encode(tokenAddress2, tokenValue2, tokenId2, tokenStandard2, accepted2, approved);
    }

    if(trade.executer == address(0) && _tradeisAccepted(index) && _tradeisApproved(index)) {
      _executeTrade(index);
    }
  }

  /**
   * @dev Verify if a trade has been approved by the token controllers.
   *
   * In case a given token has token controllers, those need to validate the trade before it gets executed.
   *
   * @param index Index of the trade to be approved.
   */
  function _tradeisApproved(uint256 index) internal view returns(bool) {
    Trade storage trade = _trades[index];

    (address tokenAddress1,,,,,bool approved1) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (address tokenAddress2,,,,,bool approved2) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));

    if(_tokenControllers[tokenAddress1].length != 0 && !approved1) {
      return false;
    }

    if(_tokenControllers[tokenAddress2].length != 0 && !approved2) {
      return false;
    }

    return true;
  }

  /**
   * @dev Execute a trade in the DVP contract if possible (e.g. if tokens have been esccrowed, in case it is required).
   *
   * This function can only be called by the executer specified at trade creation.
   * If no executer is specified, the trade can be launched by anyone.
   *
   * @param index Index of the trade to be executed.
   */
  function executeTrade(uint256 index) external {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, 'Trade is not pending');

    if(trade.executer != address(0)) {
      require(msg.sender == trade.executer, "Trade can only be executed by executer defined at trade creation");
    }

    require(_tradeisAccepted(index), "Trade has not been accepted by all token holders yet");
    
    require(_tradeisApproved(index), "Trade has not been approved by all token controllers yet");

    _executeTrade(index);
  }

  /**
   * @dev Execute a trade in the DVP contract if possible (e.g. if tokens have been esccrowed, in case it is required).
   * @param index Index of the trade to be executed.
   */
  function _executeTrade(uint256 index) internal {
    Trade storage trade = _trades[index];

    uint256 price = _getPrice(index);

    (,uint256 tokenValue1 ,,,,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (,uint256 tokenValue2 ,,,,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));

    if(price == tokenValue2) {
      _transferUsersTokens(index, Holder.Holder1, tokenValue1, false);
      _transferUsersTokens(index, Holder.Holder2, tokenValue2, false);
    } else {
      require(price <= tokenValue2, 'Price is higher than amount escrowed/authorized');
      _transferUsersTokens(index, Holder.Holder1, tokenValue1, false);
      _transferUsersTokens(index, Holder.Holder2, price, false);
      if(trade.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder2, tokenValue2 - price, true);
      }
    }
    trade.state = State.Executed;

  }

  /**
   * @dev Force a trade execution in the DVP contract by transferring tokens back to their target recipients.
   * @param index Index of the trade to be forced.
   */
  function forceTrade(uint256 index) external {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, 'Trade is not pending');

    (address tokenAddress1 ,uint256 tokenValue1 ,,, bool accepted1,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (address tokenAddress2 ,uint256 tokenValue2 ,,, bool accepted2,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));
    
    require(!(accepted1 && accepted2), "executeTrade can be called");
    require(_tokenControllers[tokenAddress1].length == 0 && _tokenControllers[tokenAddress2].length == 0, "Trade can not be forced if tokens have controllers");

    if(trade.executer != address(0)) {
      require(msg.sender == trade.executer, 'Sender is not allowed to force trade (0)');
    } else if(accepted1) {
      require(msg.sender == trade.holder1, 'Sender is not allowed to force trade (1)');
    } else if(accepted2) {
      require(msg.sender == trade.holder2, 'Sender is not allowed to force trade (2)');
    } else {
      revert("Trade can't be forced as tokens are not available so far");
    }

    if(accepted1) {
      _transferUsersTokens(index, Holder.Holder1, tokenValue1, false);
    }

    if(accepted2) {
      _transferUsersTokens(index, Holder.Holder2, tokenValue2, false);
    }

    trade.state = State.Forced;
  }

  /**
   * @dev Cancel a trade execution in the DVP contract by transferring tokens back to their initial owners.
   * @param index Index of the trade to be cancelled.
   */
  function cancelTrade(uint256 index) external {
    Trade storage trade = _trades[index];
    require(trade.state == State.Pending, 'Trade is not pending');

    (,uint256 tokenValue1 ,,, bool accepted1,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (,uint256 tokenValue2 ,,, bool accepted2,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));
    
    if(accepted1 && accepted2) {
      require(msg.sender == trade.executer || (block.timestamp >= trade.expirationDate && (msg.sender == trade.holder1 || msg.sender == trade.holder2) ), 'Sender is not allowed to cancel trade (0)');
      if(trade.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder1, tokenValue1, true);
        _transferUsersTokens(index, Holder.Holder2, tokenValue2, true);
      }
    } else if(accepted1) {
      require(msg.sender == trade.executer || (block.timestamp >= trade.expirationDate && msg.sender == trade.holder1), 'Sender is not allowed to cancel trade (1)');
      if(trade.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder1, tokenValue1, true);
      }
    } else if(accepted2) {
      require(msg.sender == trade.executer || (block.timestamp >= trade.expirationDate && msg.sender == trade.holder2), 'Sender is not allowed to cancel trade (2)');
      if(trade.tradeType == TradeType.Escrow) {
        _transferUsersTokens(index, Holder.Holder2, tokenValue2, true);
      }
    } else {
      require(msg.sender == trade.executer || msg.sender == trade.holder1 || msg.sender == trade.holder2, 'Sender is not allowed to cancel trade (3)');
    }

    trade.state = State.Cancelled;
  }

  /**
   * @dev Internal function to transfer tokens to their recipient by taking the token standard into account.
   * @param index Index of the trade the token transfer is execcuted for.
   * @param holder Sender of the tokens (currently owning the tokens).
   * @param value Amount of tokens to send.
   * @param revertTransfer If set to true + trade has been accepted, tokens need to be sent back to their initial owners instead of sent to the target recipient.
   */
  function _transferUsersTokens(uint256 index, Holder holder, uint256 value, bool revertTransfer) internal {
    Trade storage trade = _trades[index];

    address sender = (holder == Holder.Holder1) ? trade.holder1 : trade.holder2;
    address recipient = (holder == Holder.Holder1) ? trade.holder2 : trade.holder1;
    bytes memory senderTokenData = (holder == Holder.Holder1) ? trade.tokenData1 : trade.tokenData2;

    (address tokenAddress,, bytes32 tokenId, Standard tokenStandard,,) = abi.decode(senderTokenData, (address, uint256, bytes32, Standard, bool, bool));

    address currentHolder = sender;
    if(trade.tradeType == TradeType.Escrow) {
      currentHolder = address(this);
    }

    if(revertTransfer) {
      recipient = sender;
    } else {
      require(block.timestamp <= trade.expirationDate, 'Expiration date is past');
    }

    if(tokenStandard == Standard.ETH) {
      address payable payableRecipient = address(uint160(recipient));
      payableRecipient.transfer(value);
    } else if(tokenStandard == Standard.ERC20) {
      if(currentHolder == address(this)) {
        ERC20(tokenAddress).transfer(recipient, value);
      } else {
        ERC20(tokenAddress).transferFrom(currentHolder, recipient, value);
      }
    } else if(tokenStandard == Standard.ERC721) {
      ERC721(tokenAddress).transferFrom(currentHolder, recipient, uint256(tokenId));
    } else if(tokenStandard == Standard.ERC1400) {
      ERC1400(tokenAddress).operatorTransferByPartition(tokenId, currentHolder, recipient, value, "", "");
    } else {
      // OffChain
    }

  }

  /**
   * @dev Indicate whether or not the DVP contract can receive the tokens or not.
   *
   * By convention, the 32 first bytes of a token transfer to the DVP smart contract contain a flag.
   *
   *  - When tokens are transferred to DVP contract to propose a new trade. The 'data' field starts with the
   *  following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *  In this case the data structure is the the following:
   *  <tradeFlag (32 bytes)><recipient address (32 bytes)><executer address (32 bytes)><expiration date (32 bytes)><requested token data (4 * 32 bytes)>
   *
   *  - When tokens are transferred to DVP contract to accept an existing trade. The 'data' field starts with the
   *  following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *  In this case the data structure is the the following:
   *  <tradeFlag (32 bytes)><request index (32 bytes)>
   *
   * If the 'data' doesn't start with one of those flags, the DVP contract won't accept the token transfer.
   *
   * @param data Information attached to the DVP transfer.
   * @param operatorData Information attached to the DVP transfer, by the operator.
   * @return 'true' if the DVP contract can receive the tokens, 'false' if not.
   */
  function _canReceive(bytes memory data, bytes memory operatorData) internal pure returns(bool) {
    if(operatorData.length == 0) { // The reason for this check is to avoid a certificate gets interpreted as a flag by mistake
      return false;
    }
    
    bytes32 flag = _getTradeFlag(data);
    if(data.length == 256 && flag == TRADE_PROPOSAL_FLAG) {
      return true;
    } else if (data.length == 64 && flag == TRADE_ACCEPTANCE_FLAG) {
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
   * By convention, the 32 first bytes of a token transfer to the DVP smart contract contain a flag.
   *  - When tokens are transferred to DVP contract to propose a new trade. The 'data' field starts with the
   *  following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *  - When tokens are transferred to DVP contract to accept an existing trade. The 'data' field starts with the
   *  following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *
   * @param data Concatenated information about the trade proposal.
   * @return Trade flag.
   */
  function _getTradeFlag(bytes memory data) internal pure returns(bytes32 flag) {
    assembly {
      flag:= mload(add(data, 32))
    }
  }

  /**
   * By convention, when tokens are transferred to DVP contract to propose a new trade, the 'data' of a token transfer has the following structure:
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
   * @dev Retrieve the recipient from the 'data' field.
   *
   * @param data Concatenated information about the trade proposal.
   * @return Trade recipient address.
   */
  function _getTradeRecipient(bytes memory data) internal pure returns(address recipient) {
    assembly {
      recipient:= mload(add(data, 64))
    }
  }

  /**
   * @dev Retrieve the trade executer address from the 'data' field.
   *
   * @param data Concatenated information about the trade proposal.
   * @return Trade executer address.
   */
  function _getTradeExecuter(bytes memory data) internal pure returns(address executer) {
    assembly {
      executer:= mload(add(data, 96))
    }
  }

  /**
   * @dev Retrieve the expiration date from the 'data' field.
   *
   * @param data Concatenated information about the trade proposal.
   * @return Trade expiration date.
   */
  function _getTradeExpirationDate(bytes memory data) internal pure returns(uint256 expirationDate) {
    assembly {
      expirationDate:= mload(add(data, 128))
    }
  }

  /**
   * @dev Retrieve the tokenData from the 'data' field.
   *
   * @param data Concatenated information about the trade proposal.
   * @return Trade token data < 1: address > < 2: amount > < 3: id/partition > < 4: standard > < 5: accepted > < 6: approved >.
   */
  function _getTradeTokenData(bytes memory data) internal pure returns(bytes memory tokenData) {
    address tokenAddress;
    uint256 tokenAmount;
    bytes32 tokenId;
    Standard tokenStandard;
    assembly {
      tokenAddress:= mload(add(data, 160))
      tokenAmount:= mload(add(data, 192))
      tokenId:= mload(add(data, 224))
      tokenStandard:= mload(add(data, 256))
    }
    tokenData = abi.encode(tokenAddress, tokenAmount, tokenId, tokenStandard, false, false);
  }

  /**
   * @dev Retrieve the trade index from the 'data' field.
   *
   * By convention, when tokens are transferred to DVP contract to accept an existing trade, the 'data' of a token transfer has the following structure:
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
   * @return Trade index.
   */
  function _getTradeIndex(bytes memory data) internal pure returns(uint256 index) {
    assembly {
      index:= mload(add(data, 64))
    }
  }

  /**************************** TRADE EXECUTERS *******************************/

  /**
   * @dev Renounce ownership of the contract.
   */
  function renounceOwnership() public onlyOwner {
    Ownable.renounceOwnership();
    _ownedContract = false;
  }

  /**
   * @dev Get the list of trade executers as defined by the DVP contract.
   * @return List of addresses of all the trade executers.
   */
  function tradeExecuters() external view returns (address[] memory) {
    return _tradeExecuters;
  }

  /**
   * @dev Set list of trade executers for the DVP contract.
   * @param operators Trade executers addresses.
   */
  function setTradeExecuters(address[] calldata operators) external onlyOwner {
    require(_ownedContract, 'DVP contract is not owned');
    _setTradeExecuters(operators);
  }

  /**
   * @dev Set list of trade executers for the DVP contract.
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
    _setTokenControllers(tokenAddress, operators);
  }

  /**
   * @dev Set list of token controllers for a given token.
   * @param tokenAddress Token address.
   * @param operators Operators addresses.
   */
  function _setTokenControllers(address tokenAddress, address[] memory operators) internal {
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
    _setPriceOracles(tokenAddress, oracles);
  }

  /**
   * @dev Set list of price oracles for a given token.
   * @param tokenAddress Token address.
   * @param oracles Oracles addresses.
   */
  function _setPriceOracles(address tokenAddress, address[] memory oracles) internal {
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

  /****************************** DVP PRICES *********************************/

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
    require((startDate > block.timestamp + SECONDS_IN_WEEK) || startDate == 0, 'Start date needs to be set at least a week before');
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
      require(_checkPriceOracle(tokenAddress1, msg.sender), 'Price setter is not an oracle for this token (1)');
    } else if(_priceOwnership[tokenAddress2][tokenAddress1]) {
      require(_checkPriceOracle(tokenAddress2, msg.sender), 'Price setter is not an oracle for this token (2)');
    } else {
      revert("No price ownership");
    }

    _tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2] = newPrice;
  }

  /**
   * @dev Get amount of token2 to pay to acquire the token1.
   * @param index Index of the DVP request.
   */
  function getPrice(uint256 index) external view returns(uint256) {
    return _getPrice(index);
  }

  /**
   * @dev Get amount of token2 to pay to acquire the token1.
   * @param index Index of the DVP request.
   */
  function _getPrice(uint256 index) internal view returns(uint256) {  
    Trade storage trade = _trades[index];
    (address tokenAddress1, uint256 tokenValue1, bytes32 tokenId1,,,) = abi.decode(trade.tokenData1, (address, uint256, bytes32, Standard, bool, bool));
    (address tokenAddress2, uint256 tokenValue2, bytes32 tokenId2,,,) = abi.decode(trade.tokenData2, (address, uint256, bytes32, Standard, bool, bool));

    require(!(_priceOwnership[tokenAddress1][tokenAddress2] && _priceOwnership[tokenAddress2][tokenAddress1]), "Competition on price ownership");

    if(_variablePriceStartDate[tokenAddress1] == 0 || block.timestamp < _variablePriceStartDate[tokenAddress1]) {
      return tokenValue2;
    }

    if(_priceOwnership[tokenAddress1][tokenAddress2] || _priceOwnership[tokenAddress2][tokenAddress1]) {

      if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2] != 0) {
        return tokenValue1.mul(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][tokenId2]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][tokenId1] != 0) {
        return tokenValue1.div(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][tokenId1]);

      } else if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][ALL_PARTITIONS] != 0) {
        return tokenValue1.mul(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][tokenId1][ALL_PARTITIONS]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][tokenId1] != 0) {
        return tokenValue1.div(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][tokenId1]);

      } else if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][tokenId2] != 0) {
        return tokenValue1.mul(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][tokenId2]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][ALL_PARTITIONS] != 0) {
        return tokenValue1.div(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][tokenId2][ALL_PARTITIONS]);

      } else if(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][ALL_PARTITIONS] != 0) {
        return tokenValue1.mul(_tokenUnitPricesByPartition[tokenAddress1][tokenAddress2][ALL_PARTITIONS][ALL_PARTITIONS]);

      } else if(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][ALL_PARTITIONS] != 0) {
        return tokenValue1.div(_tokenUnitPricesByPartition[tokenAddress2][tokenAddress1][ALL_PARTITIONS][ALL_PARTITIONS]);

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
  function getTrade(uint256 index) external view returns(address, address, address, uint256, bytes memory, bytes memory, TradeType, State) {
    Trade storage trade = _trades[index];
    return (
      trade.holder1,
      trade.holder2,
      trade.executer,
      trade.expirationDate,
      trade.tokenData1,
      trade.tokenData2,
      trade.tradeType,
      trade.state
    );
  }

  /**
   * @dev Get the total number of requests in the DVP contract.
   * @return Total number of requests in the DVP contract.
   */
  function getNbTrades() external view returns(uint256) {
    return _index;
  }

  /**
   * @dev Get global acceptance status for a given a trade.
   * @return Acceptance status.
   */
  function getTradeAcceptanceStatus(uint256 index) external view returns(bool) {
    return _tradeisAccepted(index);
  }

  /**
   * @dev Get global approval status for a given a trade.
   * @return Approval status.
   */
  function getTradeApprovalStatus(uint256 index) external view returns(bool) {
    return _tradeisApproved(index);
  }

 }
