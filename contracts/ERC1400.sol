/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*
* TODO
* - Do we need to modify the access to documents
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";

import "./IERC1400.sol";
import "./token/ERC1410/ERC1410.sol";


contract ERC1400 is IERC1400, ERC1410, MinterRole {

  struct Document {
    string docURI;
    bytes32 docHash;
  }

  // Mapping for token URIs
  mapping(bytes32 => Document) internal _documents;

  // Indicates whether the token can still be minted/issued by the minter or not anymore
  bool internal _isIssuable;

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

  /**
   * [ERC1400 INTERFACE (1/8)]
   * @dev External function to access a document associated with the token.
   * @param name short name (represented as a bytes32) associated to the document.
   * @return Requested document + document hash
   */
  function getDocument(bytes32 name) external view returns (string, bytes32) {
    require(bytes(_documents[name].docURI).length != 0);
    return (
      _documents[name].docURI,
      _documents[name].docHash
    );
  }

  /**
   * [ERC1400 INTERFACE (2/8)]
   * @dev External function to accociate a document with the token.
   * @param name short name (represented as a bytes32) associated to the document.
   * @param uri document content.
   * @param documentHash hash of the document [optional parameter].
   */
  function setDocument(bytes32 name, string uri, bytes32 documentHash) external onlyOwner {
    _documents[name] = Document({
      docURI: uri,
      docHash: documentHash
    });
  }

  /**
   * [ERC1400 INTERFACE (3/8)]
   * @dev External function to know if the token can be controlled by operators.
   * If a token returns FALSE for isControllable() then it MUST:
   *  - always return FALSE in the future.
   *  - return empty lists for defaultOperators and defaultOperatorsByTranche.
   *  - never add addresses for defaultOperators and defaultOperatorsByTranche.
   * @return bool TRUE if the token can still be controlled by operators, FALSE if it can't anymore.
   */
  function isControllable() external view returns (bool) {
    return _isControllable;
  }

  /**
   * [ERC1400 INTERFACE (4/8)]
   * @dev External function to know if new tokens can be minted/issued in the future.
   * @return bool TRUE if tokens can still be minted/issued by the minter, FALSE if they can't anymore.
   */
  function isIssuable() external view returns (bool) {
    return _isIssuable;
  }

  /**
   * [ERC1400 INTERFACE (5/8)]
   * @dev External to mint/issue tokens from a specific tranche.
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which we want to mint/issue tokens.
   * @param amount Number of tokens minted.
   * @param data Information attached to the minting, and intended for the token holder (to) [contains the conditional ownership certificate].
   */
  function issueByTranche(bytes32 tranche, address tokenHolder, uint256 amount, bytes data)
    external
    onlyMinter
    isValidCertificate(data)
  {
    _issueByTranche(tranche, msg.sender, tokenHolder, amount, data, "");
  }

  /**
   * [ERC1400 INTERFACE (6/8)]
   * @dev External to redeem tokens of a specific tranche.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens minted.
   * @param data Information attached to the redeem, and intended for the token holder (from) [contains the conditional ownership certificate].
   */
  function redeemByTranche(bytes32 tranche, uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _redeemByTranche(tranche, msg.sender, msg.sender, amount, data, "");
  }

  /**
   * [ERC1400 INTERFACE (7/8)]
   * @dev External to redeem tokens of a specific tranche.
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which we want to redeem tokens.
   * @param amount Number of tokens minted.
   * @param data Information attached to the redeem, and intended for the token holder (from).
   * @param operatorData Information attached to the redeem by the operator [contains the conditional ownership certificate].
   */
  function operatorRedeemByTranche(bytes32 tranche, address tokenHolder, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (tokenHolder == address(0)) ? msg.sender : tokenHolder;
    require(_isOperatorFor(msg.sender, _from, _isControllable) || _isOperatorForTranche(tranche, msg.sender, _from));

    _redeemByTranche(tranche, msg.sender, _from, amount, data, operatorData);
  }

  /** [TODO - TO BE REVIEWED]
   * [ERC1400 INTERFACE (8/8)]
   * @dev External function to know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param from Token holder whose tokens will be transferred.
   * @param to Token recipient.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   * @param data Information attached to the transfer, and intended for the token holder (from) [can contain the destination tranche].
   * @return byte ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return bytes32 additional bytes32 parameter that can be used to define
   *  application specific reason codes with additional details (for example the
   *  transfer restriction rule responsible for making the send operation invalid).
   * @return bytes32 destination tranche.
   */
  function canSend(address from, address to, bytes32 tranche, uint256 amount, bytes data)
    external
    view
    returns (byte, bytes32, bytes32)
  {
    byte reasonCode;
    address _from = (from == address(0)) ? msg.sender : from;

    address recipientImplementation;
    address senderImplementation;

    recipientImplementation = interfaceAddr(to, "ERC777TokensRecipient");
    senderImplementation = interfaceAddr(from, "ERC777TokensSender");

    if(!_isMultiple(amount)) {
      reasonCode = hex"A9";   // 0xA9	Transfer Blocked - Token granularity
    } else if (false) {
      reasonCode = hex"A8";   // 0xA8	Transfer Blocked - Token restriction
    } else if (false) {
      reasonCode = hex"A7";   // 0xA7	Transfer Blocked - Identity restriction
    } else if (
      (recipientImplementation != address(0))
      && !IERC777TokensRecipient(recipientImplementation).canReceive(from, to, tranche, amount, data)
    ) {
      reasonCode = hex"A6";   // 0xA6	Transfer Blocked - Receiver not eligible
    } else if (to == address(0)) {
        reasonCode = hex"A6";   // 0xA6	Transfer Blocked - Receiver not eligible
    } else if (
      (senderImplementation != address(0))
      && !IERC777TokensSender(senderImplementation).canSend(from, to, tranche, amount, data)
    ) {
      reasonCode = hex"A5";   // 0xA5	Transfer Blocked - Sender not eligible
    } else if (
      ((tranche == "") && (_balances[from] < amount))
      || ((tranche != "") && (_balanceOfByTranche[from][tranche] < amount))
    ) {
      reasonCode = hex"A4";   // 0xA4	Transfer Blocked - Sender balance insufficient
    } else if (false) {
      reasonCode = hex"A3";   // 0xA3	Transfer Blocked - Sender lockup period not ended
    } else if (false) {
      reasonCode = hex"A2";   // 0xA2	Transfer Verified - Off-Chain approval for restricted token
    } else if (true) {
      reasonCode = hex"A1";   // 0xA1	Transfer Verified - On-Chain approval for restricted token
    } else {
      reasonCode = hex"A0";   // 0xA0	Transfer Verified - Unrestricted
    }

    return(reasonCode, "", _getDestinationTranche(data));
  }

  /**
   * @dev Internal function to mint/issue tokens from a specific tranche.
   * @param toTranche Name of the tranche.
   * @param operator The address performing the mint/issuance.
   * @param to Token recipient.
   * @param amount Number of tokens to mint/issue.
   * @param data Information attached to the mint/issuance, and intended for the token holder (to) [contains the destination tranche].
   * @param operatorData Information attached to the mint/issuance by the operator [contains the conditional ownership certificate].
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
    require(_isIssuable);

    _mint(operator, to, amount, data, operatorData);
    _addTokenToTranche(to, toTranche, amount);

    emit IssuedByTranche(toTranche, operator, to, amount, data, operatorData);
  }

  /**
   * @dev Internal function to redeem tokens of a specific tranche.
   * @param fromTranche Name of the tranche.
   * @param operator The address performing the mint/issuance.
   * @param from Token holder whose tokens will be redeemed.
   * @param amount Number of tokens to redeem.
   * @param data Information attached to the burn/redeem, and intended for the token holder (from).
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
    require(_balanceOfByTranche[from][fromTranche] >= amount); // ensure enough funds

    _removeTokenFromTranche(from, fromTranche, amount);
    _burn(operator, from, amount, data, operatorData);

    emit RedeemedByTranche(fromTranche, operator, from, amount, data, operatorData);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev External function to definitely renounce the possibility to control tokens
   * on behalf of investors.
   * Once set to false, '_isControllable' can never be set to TRUE again.
   */
  function renounceControl() external onlyOwner {
    require(_defaultOperators.length == 0);

    for (uint i = 0; i < _totalTranches.length; i++) {
      require(_defaultOperatorsByTranche[_totalTranches[i]].length == 0);
    }
    _isControllable = false;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev External function to definitely renounce the possibility to issue new tokens.
   * Once set to false, '_isIssuable' can never be set to TRUE again.
   */
  function renounceIssuance() external onlyOwner {
    _isIssuable = false;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of tokenHolder.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator.
   * @return true if operator is an operator of tokenHolder and false otherwise.
   */
  function isOperatorFor(address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorFor(operator, tokenHolder, _isControllable);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Burn the amount of tokens from the address msg.sender.
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, by the token holder [contains the conditional ownership certificate].
   */
  function burn(uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _redeemByDefaultTranches(msg.sender, msg.sender, amount, data, "");
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Burn the amount of tokens on behalf of the address from.
   * @param from Token holder whose tokens will be burned (or address(0) to set from to msg.sender).
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, and intended for the token holder (from).
   * @param operatorData Information attached to the burn by the operator [contains the conditional ownership certificate].
   */
  function operatorBurn(address from, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from, _isControllable));

    _redeemByDefaultTranches(msg.sender, _from, amount, data, operatorData);
  }

  /**
  * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Internal function to redeem tokens from a default tranches
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
    require(_defaultTranches[from].length != 0);

    bytes32[] memory _tranches;
    uint256[] memory _amounts;

    (_tranches, _amounts) = _getDefaultTranchesForAmount(from, amount);

    require(_tranches.length == _amounts.length);

    for (uint i = 0; i < _tranches.length; i++) {
      _redeemByTranche(_tranches[i], operator, from, _amounts[i], data, operatorData);
      if(_amounts[i] == 0) {break;}
    }

  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev External function to add a default operator for the token.
   * @param operator Address to set as a default operator.
   */
  function addDefaultOperator(address operator) external onlyOwner {
    require(_isControllable);
    _addDefaultOperator(operator);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev External function to remove a default operator for the token.
   * @param operator Address to set as a default operator.
   */
  function removeDefaultOperator(address operator) external onlyOwner {
    _removeDefaultOperator(operator);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev External function to add a default operator for the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function addDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyOwner {
    require(_isControllable);
    _addDefaultOperatorByTranche(tranche, operator);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev External function to remove a default operator for the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function removeDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyOwner {
    _removeDefaultOperatorByTranche(tranche, operator);
  }

}
