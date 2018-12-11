/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";

import "./IERC1400.sol";
import "./token/ERC1410/ERC1410.sol";


/**
 * @title ERC1400
 * @dev ERC1400 logic
 */
contract ERC1400 is IERC1400, ERC1410, MinterRole {

  struct Document {
    string docURI;
    bytes32 docHash;
  }

  // Mapping for token URIs.
  mapping(bytes32 => Document) internal _documents;

  // Indicate whether the token can still be minted/issued by the minter or not anymore.
  bool internal _isIssuable;

  /**
   * @dev Modifier to verify if token is issuable.
   */
  modifier issuableToken() {
    require(_isIssuable, "A8, Transfer Blocked - Token restriction");
    _;
  }

  /**
   * [ERC1400 CONSTRUCTOR]
   * @dev Initialize ERC1400 + register
   * the contract implementation in ERC820Registry.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param defaultOperators Array of initial default operators.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, mint,
   * burn (Cf. CertificateController.sol).
   */
  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner
  )
    public
    ERC1410(name, symbol, granularity, defaultOperators, certificateSigner)
  {
    setInterfaceImplementation("ERC1400Token", this);
    _isControllable = true;
    _isIssuable = true;
  }

  /********************** ERC1400 EXTERNAL FUNCTIONS **************************/

  /**
   * [ERC1400 INTERFACE (1/8)]
   * @dev Access a document associated with the token.
   * @param name Short name (represented as a bytes32) associated to the document.
   * @return Requested document + document hash.
   */
  function getDocument(bytes32 name) external view returns (string, bytes32) {
    require(bytes(_documents[name].docURI).length != 0, "Action Blocked - Empty document");
    return (
      _documents[name].docURI,
      _documents[name].docHash
    );
  }

  /**
   * [ERC1400 INTERFACE (2/8)]
   * @dev Associate a document with the token.
   * @param name Short name (represented as a bytes32) associated to the document.
   * @param uri Document content.
   * @param documentHash Hash of the document [optional parameter].
   */
  function setDocument(bytes32 name, string uri, bytes32 documentHash) external onlyOwner {
    _documents[name] = Document({
      docURI: uri,
      docHash: documentHash
    });
  }

  /**
   * [ERC1400 INTERFACE (3/8)]
   * @dev Know if the token can be controlled by operators.
   * If a token returns 'false' for 'isControllable()'' then it MUST:
   *  - always return 'false' in the future.
   *  - return empty lists for 'defaultOperators' and 'defaultOperatorsByTranche'.
   *  - never add addresses for 'defaultOperators' and 'defaultOperatorsByTranche'.
   * @return bool 'true' if the token can still be controlled by operators, 'false' if it can't anymore.
   */
  function isControllable() external view returns (bool) {
    return _isControllable;
  }

  /**
   * [ERC1400 INTERFACE (4/8)]
   * @dev Know if new tokens can be minted/issued in the future.
   * @return bool 'true' if tokens can still be minted/issued by the minter, 'false' if they can't anymore.
   */
  function isIssuable() external view returns (bool) {
    return _isIssuable;
  }

  /**
   * [ERC1400 INTERFACE (5/8)]
   * @dev Mint/issue tokens from a specific tranche.
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which we want to mint/issue tokens.
   * @param amount Number of tokens minted.
   * @param data Information attached to the minting, and intended for the
   * token holder ('to'). [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function issueByTranche(bytes32 tranche, address tokenHolder, uint256 amount, bytes data)
    external
    onlyMinter
    issuableToken
    isValidCertificate(data)
  {
    _issueByTranche(tranche, msg.sender, tokenHolder, amount, data, "");
  }

  /**
   * [ERC1400 INTERFACE (6/8)]
   * @dev Redeem tokens of a specific tranche.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens minted.
   * @param data Information attached to the redeem, and intended for the
   * token holder ('from'). [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function redeemByTranche(bytes32 tranche, uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _redeemByTranche(tranche, msg.sender, msg.sender, amount, data, "");
  }

  /**
   * [ERC1400 INTERFACE (7/8)]
   * @dev Redeem tokens of a specific tranche.
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which we want to redeem tokens.
   * @param amount Number of tokens minted.
   * @param data Information attached to the redeem, and intended for the token holder ('from').
   * @param operatorData Information attached to the redeem by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function operatorRedeemByTranche(bytes32 tranche, address tokenHolder, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (tokenHolder == address(0)) ? msg.sender : tokenHolder;
    require(_isOperatorFor(msg.sender, _from, _isControllable)
      || _isOperatorForTranche(tranche, msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    _redeemByTranche(tranche, msg.sender, _from, amount, data, operatorData);
  }

  /**
   * [ERC1400 INTERFACE (8/8)]
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param tranche Name of the tranche.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the transfer, and intended for the token holder ('from'). [Can contain the destination tranche]
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the send operation invalid).
   * @return Destination tranche.
   */
  function canSend(bytes32 tranche, address to, uint256 amount, bytes data)
    external
    view
    returns (byte, bytes32, bytes32)
  {
    byte reasonCode;

    if(_checkCertificate(data, 0, 0xfb913d14)) { // 4 first bytes of keccak256(sendByTranche(bytes32,address,uint256,bytes))

      if((_balances[msg.sender] >= amount) && (_balanceOfByTranche[msg.sender][tranche] >= amount)) {

        if(to != address(0)) {

          address senderImplementation;
          address recipientImplementation;
          senderImplementation = interfaceAddr(msg.sender, "ERC777TokensSender");
          recipientImplementation = interfaceAddr(to, "ERC777TokensRecipient");

          if((senderImplementation != address(0))
            && !IERC777TokensSender(senderImplementation).canSend(tranche, msg.sender, to, amount, data, "")) {

              reasonCode = hex"A5"; // Transfer Blocked - Sender not eligible

          } else if((recipientImplementation != address(0))
            && !IERC777TokensRecipient(recipientImplementation).canReceive(tranche, msg.sender, to, amount, data, "")) {

              reasonCode = hex"A6"; // Transfer Blocked - Receiver not eligible

          } else {
            if(_isMultiple(amount)) {
              reasonCode = hex"A2"; // Transfer Verified - Off-Chain approval for restricted token

            } else {
              reasonCode = hex"A9"; // Transfer Blocked - Token granularity
            }
          }

        } else {
          reasonCode = hex"A6"; // Transfer Blocked - Receiver not eligible
        }

      } else {
        reasonCode = hex"A4"; // Transfer Blocked - Sender balance insufficient
      }

    } else {
      reasonCode = hex"A3"; // Transfer Blocked - Sender lockup period not ended
    }

    return(reasonCode, "", tranche);
  }

  /********************** ERC1400 INTERNAL FUNCTIONS **************************/

  /**
   * [INTERNAL]
   * @dev Mint/issue tokens from a specific tranche.
   * @param toTranche Name of the tranche.
   * @param operator The address performing the mint/issuance.
   * @param to Token recipient.
   * @param amount Number of tokens to mint/issue.
   * @param data Information attached to the mint/issuance, and intended for the token holder ('to'). [Contains the destination tranche]
   * @param operatorData Information attached to the mint/issuance by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function _issueByTranche(
    bytes32 toTranche,
    address operator,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
  {
    _mint(operator, to, amount, data, operatorData);
    _addTokenToTranche(to, toTranche, amount);

    emit IssuedByTranche(toTranche, operator, to, amount, data, operatorData);
  }

  /**
   * [INTERNAL]
   * @dev Redeem tokens of a specific tranche.
   * @param fromTranche Name of the tranche.
   * @param operator The address performing the mint/issuance.
   * @param from Token holder whose tokens will be redeemed.
   * @param amount Number of tokens to redeem.
   * @param data Information attached to the burn/redeem, and intended for the token holder ('from').
   * @param operatorData Information attached to the burn/redeem by the operator.
   */
  function _redeemByTranche(
    bytes32 fromTranche,
    address operator,
    address from,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
  {
    require(_balanceOfByTranche[from][fromTranche] >= amount, "A4: Transfer Blocked - Sender balance insufficient");

    _removeTokenFromTranche(from, fromTranche, amount);
    _burn(operator, from, amount, data, operatorData);

    emit RedeemedByTranche(fromTranche, operator, from, amount, data, operatorData);
  }

  /********************** ERC1400 OPTIONAL FUNCTIONS **************************/

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Definitely renounce the possibility to control tokens
   * on behalf of investors.
   * Once set to false, '_isControllable' can never be set to 'true' again.
   */
  function renounceControl() external onlyOwner {
    _isControllable = false;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Definitely renounce the possibility to issue new tokens.
   * Once set to false, '_isIssuable' can never be set to 'true' again.
   */
  function renounceIssuance() external onlyOwner {
    _isIssuable = false;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Add a default operator for the token.
   * @param operator Address to set as a default operator.
   */
  function addDefaultOperator(address operator) external onlyOwner controllableToken {
    _addDefaultOperator(operator);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Remove default operator of the token.
   * @param operator Address to remove from default operators.
   */
  function removeDefaultOperator(address operator) external onlyOwner {
    _removeDefaultOperator(operator);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Add a default operator for a specific tranche of the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function addDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyOwner controllableToken {
    _addDefaultOperatorByTranche(tranche, operator);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Remove default operator of a specific tranche of the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function removeDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyOwner {
    _removeDefaultOperatorByTranche(tranche, operator);
  }

  /************* ERC1410/ERC777 BACKWARDS RETROCOMPATIBILITY ******************/

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of 'tokenHolder'.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator.
   * @return 'true' if operator is an operator of 'tokenHolder' and 'false' otherwise.
   */
  function isOperatorFor(address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorFor(operator, tokenHolder, _isControllable);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC1410 METHOD]
   * @dev Burn the amount of tokens from the address 'msg.sender'.
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function burn(uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _redeemByDefaultTranches(msg.sender, msg.sender, amount, data, "");
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC1410 METHOD]
   * @dev Burn the amount of tokens on behalf of the address 'from'.
   * @param from Token holder whose tokens will be burned (or 'address(0)' to set from to 'msg.sender').
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, and intended for the token holder ('from').
   * @param operatorData Information attached to the burn by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function operatorBurn(address from, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from, _isControllable), "A7: Transfer Blocked - Identity restriction");

    _redeemByDefaultTranches(msg.sender, _from, amount, data, operatorData);
  }

  /**
  * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Redeem tokens from a default tranches.
   * @param operator The address performing the redeem.
   * @param from Token holder.
   * @param amount Number of tokens to redeem.
   * @param data Information attached to the burn/redeem, and intended for the token holder (from).
   * @param operatorData Information attached to the burn/redeem by the operator.
   */
  function _redeemByDefaultTranches(
    address operator,
    address from,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
  {
    require(_defaultTranches[from].length != 0, "A8: Transfer Blocked - Token restriction");

    uint256 _remainingAmount = amount;
    uint256 _localBalance;

    for (uint i = 0; i < _defaultTranches[from].length; i++) {
      _localBalance = _balanceOfByTranche[from][_defaultTranches[from][i]];
      if(_remainingAmount <= _localBalance) {
        _redeemByTranche(_defaultTranches[from][i], operator, from, _remainingAmount, data, operatorData);
        _remainingAmount = 0;
        break;
      } else {
        _redeemByTranche(_defaultTranches[from][i], operator, from, _localBalance, data, operatorData);
        _remainingAmount = _remainingAmount - _localBalance;
      }
    }

    require(_remainingAmount == 0, "A8: Transfer Blocked - Token restriction");
  }

}
