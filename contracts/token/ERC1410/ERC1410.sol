/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

import "./IERC1410.sol";
import "../ERC777/ERC777.sol";

/**
 * @title ERC1410
 * @dev ERC1410 logic
 */
contract ERC1410 is IERC1410, ERC777 {

  // Indicate whether the token can still be controlled by operators or not anymore.
  bool internal _isControllable;

  /******************** Mappings to find tranche ******************************/
  // List of tranches.
  bytes32[] internal _totalTranches;

  // Mapping from tranche to global balance of corresponding tranche.
  mapping (bytes32 => uint256) internal _totalSupplyByTranche;

  // Mapping from tokenHolder to their tranches.
  mapping (address => bytes32[]) internal _tranchesOf;

  // Mapping from (tokenHolder, tranche) to balance of corresponding tranche.
  mapping (address => mapping (bytes32 => uint256)) internal _balanceOfByTranche;

  // Mapping from tokenHolder to their default tranches (for ERC777 and ERC20 compatibility).
  mapping (address => bytes32[]) internal _defaultTranches;
  /****************************************************************************/

  /**************** Mappings to find tranche operators ************************/
  // Mapping from (tokenHolder, tranche, operator) to 'approved for tranche' status. [TOKEN-HOLDER-SPECIFIC]
  mapping (address => mapping (bytes32 => mapping (address => bool))) internal _trancheAuthorized;

  // Mapping from (tokenHolder, tranche, operator) to 'revoked for tranche' status. [TOKEN-HOLDER-SPECIFIC]
  mapping (address => mapping (bytes32 => mapping (address => bool))) internal _trancheRevokedDefaultOperator;

  // Mapping from tranche to default operators for the tranche. [NOT TOKEN-HOLDER-SPECIFIC]
  mapping (bytes32 => address[]) internal _defaultOperatorsByTranche;

  // Mapping from (tranche, operator) to defaultOperatorByTranche status. [NOT TOKEN-HOLDER-SPECIFIC]
  mapping (bytes32 => mapping (address => bool)) internal _isDefaultOperatorByTranche;
  /****************************************************************************/

  /**
   * @dev Modifier to verify if token is controllable.
   */
  modifier controllableToken() {
    require(_isControllable, "A8: Transfer Blocked - Token restriction");
    _;
  }

  /**
   * [ERC1410 CONSTRUCTOR]
   * @dev Initialize ERC1410 parameters + register
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
    ERC777(name, symbol, granularity, defaultOperators, certificateSigner)
  {
    setInterfaceImplementation("ERC1410Token", this);
  }

  /********************** ERC1410 EXTERNAL FUNCTIONS **************************/

  /**
   * [ERC1410 INTERFACE (1/12)]
   * @dev Get balance of a tokenholder for a specific tranche.
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which the balance is returned.
   * @return Amount of token of tranche 'tranche' held by 'tokenHolder' in the token contract.
   */
  function balanceOfByTranche(bytes32 tranche, address tokenHolder) external view returns (uint256) {
    return _balanceOfByTranche[tokenHolder][tranche];
  }

  /**
   * [ERC1410 INTERFACE (2/12)]
   * @dev Get tranches index of a tokenholder.
   * @param tokenHolder Address for which the tranches index are returned.
   * @return Array of tranches index of 'tokenHolder'.
   */
  function tranchesOf(address tokenHolder) external view returns (bytes32[]) {
    return _tranchesOf[tokenHolder];
  }

  /**
   * [ERC1410 INTERFACE (3/12)]
   * @dev Send tokens from a specific tranche.
   * @param tranche Name of the tranche.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return Destination tranche.
   */
  function sendByTranche(
    bytes32 tranche,
    address to,
    uint256 amount,
    bytes data
  )
    external
    isValidCertificate(data)
    returns (bytes32)
  {
    return _sendByTranche(tranche, msg.sender, msg.sender, to, amount, data, "");
  }

  /**
   * [ERC1410 INTERFACE (4/12)]
   * @dev Send tokens from specific tranches.
   * @param tranches Name of the tranches.
   * @param to Token recipient.
   * @param amounts Number of tokens to send.
   * @param data Information attached to the send, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return Destination tranches.
   */
  function sendByTranches(
    bytes32[] tranches,
    address to,
    uint256[] amounts,
    bytes data
  )
    external
    isValidCertificate(data)
    returns (bytes32[])
  {
    require(tranches.length == amounts.length, "A8: Transfer Blocked - Token restriction");
    bytes32[] memory destinationTranches = new bytes32[](tranches.length);

    for (uint i = 0; i < tranches.length; i++) {
      destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, msg.sender, to, amounts[i], data, "");
    }

    return destinationTranches;
  }

  /**
   * [ERC1410 INTERFACE (5/12)]
   * @dev Send tokens from a specific tranche through an operator.
   * @param tranche Name of the tranche.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder ('from'). [Contains the destination tranche]
   * @param operatorData Information attached to the send by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return Destination tranche.
   */
  function operatorSendByTranche(
    bytes32 tranche,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    external
    isValidCertificate(operatorData)
    returns (bytes32)
  {
    address _from = (from == address(0)) ? msg.sender : from;
    require(_isOperatorFor(msg.sender, _from, _isControllable)
      || _isOperatorForTranche(tranche, msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    return _sendByTranche(tranche, msg.sender, _from, to, amount, data, operatorData);
  }

  /**
   * [ERC1410 INTERFACE (6/12)]
   * @dev Send tokens from specific tranches through an operator.
   * @param tranches Name of the tranches.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amounts Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder ('from'). [Contains the destination tranche]
   * @param operatorData Information attached to the send by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return Destination tranches.
   */
  function operatorSendByTranches(
    bytes32[] tranches,
    address from,
    address to,
    uint256[] amounts,
    bytes data,
    bytes operatorData
  )
    external
    isValidCertificate(operatorData)
    returns (bytes32[])
  {
    require(tranches.length == amounts.length, "A8: Transfer Blocked - Token restriction");
    bytes32[] memory destinationTranches = new bytes32[](tranches.length);
    address _from = (from == address(0)) ? msg.sender : from;

    for (uint i = 0; i < tranches.length; i++) {
      require(_isOperatorFor(msg.sender, _from, _isControllable)
        || _isOperatorForTranche(tranches[i], msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

      destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, _from, to, amounts[i], data, operatorData);
    }

    return destinationTranches;
  }

  /**
   * [ERC1410 INTERFACE (7/12)]
   * @dev Get default tranches to send from.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * For example, a security token may return the bytes32("unrestricted").
   * @param tokenHolder Address for which we want to know the default tranches.
   * @return Array of default tranches.
   */
  function getDefaultTranches(address tokenHolder) external view returns (bytes32[]) {
    return _defaultTranches[tokenHolder];
  }

  /**
   * [ERC1410 INTERFACE (8/12)]
   * @dev Set default tranches to send from.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * @param tranches tranches to use by default when not specified.
   */
  function setDefaultTranches(bytes32[] tranches) external {
    _defaultTranches[msg.sender] = tranches;
  }

  /**
   * [ERC1410 INTERFACE (9/12)]
   * @dev Get default operators for a given tranche.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * @param tranche Name of the tranche.
   * @return Array of default operators for tranche.
   */
  function defaultOperatorsByTranche(bytes32 tranche) external view returns (address[]) {
    if (_isControllable) {
      return _defaultOperatorsByTranche[tranche];
    } else {
      return new address[](0);
    }
  }

  /**
   * [ERC1410 INTERFACE (10/12)]
   * @dev Set 'operator' as an operator for 'msg.sender' for a given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address to set as an operator for 'msg.sender'.
   */
  function authorizeOperatorByTranche(bytes32 tranche, address operator) external {
    _trancheRevokedDefaultOperator[msg.sender][tranche][operator] = false;
    _trancheAuthorized[msg.sender][tranche][operator] = true;
    emit AuthorizedOperatorByTranche(tranche, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (11/12)]
   * @dev Remove the right of the operator address to be an operator on a given
   * tranche for 'msg.sender' and to send and burn tokens on its behalf.
   * @param tranche Name of the tranche.
   * @param operator Address to rescind as an operator on given tranche for 'msg.sender'.
   */
  function revokeOperatorByTranche(bytes32 tranche, address operator) external {
    _trancheRevokedDefaultOperator[msg.sender][tranche][operator] = true;
    _trancheAuthorized[msg.sender][tranche][operator] = false;
    emit RevokedOperatorByTranche(tranche, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (12/12)]
   * @dev Indicate whether the operator address is an operator of the tokenHolder
   * address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   * @return 'true' if 'operator' is an operator of 'tokenHolder' for tranche 'tranche' and 'false' otherwise.
   */
  function isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorForTranche(tranche, operator, tokenHolder);
  }

  /********************** ERC1410 INTERNAL FUNCTIONS **************************/

  /**
   * [INTERNAL]
   * @dev Indicate whether the operator address is an operator of the tokenHolder
   * address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   * @return 'true' if 'operator' is an operator of 'tokenHolder' for tranche 'tranche' and 'false' otherwise.
   */
   function _isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) internal view returns (bool) {
     return (_trancheAuthorized[tokenHolder][tranche][operator]
       || (_isDefaultOperatorByTranche[tranche][operator] && !_trancheRevokedDefaultOperator[tokenHolder][tranche][operator])
       || (_isDefaultOperatorByTranche[tranche][operator] && _isControllable)
     );
   }

  /**
   * [INTERNAL]
   * @dev Send tokens from a specific tranche.
   * @param fromTranche Tranche of the tokens to send.
   * @param operator The address performing the send.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder ('from'). [Can contain the destination tranche]
   * @param operatorData Information attached to the send by the operator.
   * @return Destination tranche.
   */
  function _sendByTranche(
    bytes32 fromTranche,
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
    returns (bytes32)
  {
    require(_balanceOfByTranche[from][fromTranche] >= amount, "A4: Transfer Blocked - Sender balance insufficient"); // ensure enough funds

    bytes32 toTranche = fromTranche;
    if(operatorData.length != 0 && data.length != 0) {
      toTranche = _getDestinationTranche(data);
    }

    _removeTokenFromTranche(from, fromTranche, amount);
    _sendTo(operator, from, to, amount, data, operatorData, true);
    _addTokenToTranche(to, toTranche, amount);

    emit SentByTranche(fromTranche, operator, from, to, amount, data, operatorData);

    if(toTranche != fromTranche) {
      emit ChangedTranche(fromTranche, toTranche, amount);
    }

    return toTranche;
  }

  /**
   * [INTERNAL]
   * @dev Remove a token from a specific tranche.
   * @param from Token holder.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   */
  function _removeTokenFromTranche(address from, bytes32 tranche, uint256 amount) internal {
    _balanceOfByTranche[from][tranche] = _balanceOfByTranche[from][tranche].sub(amount);
    _totalSupplyByTranche[tranche] = _totalSupplyByTranche[tranche].sub(amount);

    // If the balance of the TokenHolder's tranche is zero, finds and deletes the tranche.
    if(_balanceOfByTranche[from][tranche] == 0) {
      for (uint i = 0; i < _tranchesOf[from].length; i++) {
        if(_tranchesOf[from][i] == tranche) {
          _tranchesOf[from][i] = _tranchesOf[from][_tranchesOf[from].length - 1];
          delete _tranchesOf[from][_tranchesOf[from].length - 1];
          _tranchesOf[from].length--;
          break;
        }
      }
    }

    // If the total supply is zero, finds and deletes the tranche.
    if(_totalSupplyByTranche[tranche] == 0) {
      for (i = 0; i < _totalTranches.length; i++) {
        if(_totalTranches[i] == tranche) {
          _totalTranches[i] = _totalTranches[_totalTranches.length - 1];
          delete _totalTranches[_totalTranches.length - 1];
          _totalTranches.length--;
          break;
        }
      }
    }
  }

  /**
   * [INTERNAL]
   * @dev Add a token to a specific tranche.
   * @param to Token recipient.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   */
  function _addTokenToTranche(address to, bytes32 tranche, uint256 amount) internal {
    if(amount != 0) {
      if(_balanceOfByTranche[to][tranche] == 0) {
        _tranchesOf[to].push(tranche);
      }
      _balanceOfByTranche[to][tranche] = _balanceOfByTranche[to][tranche].add(amount);

      if(_totalSupplyByTranche[tranche] == 0) {
        _totalTranches.push(tranche);
      }
      _totalSupplyByTranche[tranche] = _totalSupplyByTranche[tranche].add(amount);
    }
  }

  /**
   * [INTERNAL]
   * @dev Retrieve the destination tranche from the 'data' field.
   * Basically, this function only converts the bytes variable into a bytes32 variable.
   * @param data Information attached to the send [Contains the destination tranche].
   * @return Destination tranche.
   */
  function _getDestinationTranche(bytes data) internal pure returns(bytes32 toTranche) {
    assembly {
      toTranche := mload(add(data, 32))
    }
  }

  /********************* ERC1410 OPTIONAL FUNCTIONS ***************************/

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Get list of existing tranches.
   * @return Array of all exisiting tranches.
   */
  function totalTranches() external view returns (bytes32[]) {
    return _totalTranches;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Add a default operator for a specific tranche of the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function _addDefaultOperatorByTranche(bytes32 tranche, address operator) internal {
    require(!_isDefaultOperatorByTranche[tranche][operator], "Action Blocked - Already a default operator");
    _defaultOperatorsByTranche[tranche].push(operator);
    _isDefaultOperatorByTranche[tranche][operator] = true;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Remove default operator of a specific tranche of the token.
   * @param tranche Name of the tranche.
   * @param operator Address to remove from default operators of tranche.
   */
  function _removeDefaultOperatorByTranche(bytes32 tranche, address operator) internal {
    require(_isDefaultOperatorByTranche[tranche][operator], "Action Blocked - Not a default operator");

    for (uint i = 0; i < _defaultOperatorsByTranche[tranche].length; i++){
      if(_defaultOperatorsByTranche[tranche][i] == operator) {
        _defaultOperatorsByTranche[tranche][i] = _defaultOperatorsByTranche[tranche][_defaultOperatorsByTranche[tranche].length - 1];
        delete _defaultOperatorsByTranche[tranche][_defaultOperatorsByTranche[tranche].length-1];
        _defaultOperatorsByTranche[tranche].length--;
        break;
      }
    }
    _isDefaultOperatorByTranche[tranche][operator] = false;
  }

  /************** ERC777 BACKWARDS RETROCOMPATIBILITY *************************/

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Get the list of default operators as defined by the token contract.
   * @return List of addresses of all the default operators.
   */
  function defaultOperators() external view returns (address[]) {
    return _getDefaultOperators(_isControllable);
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Send the amount of tokens from the address 'msg.sender' to the address 'to'.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function sendTo(address to, uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _sendByDefaultTranches(msg.sender, msg.sender, to, amount, data, "");
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Send the amount of tokens on behalf of the address from to the address to.
   * @param from Token holder (or 'address(0)'' to set from to 'msg.sender').
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder ('from'). [Can contain the destination tranche]
   * @param operatorData Information attached to the send by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function operatorSendTo(address from, address to, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from, _isControllable), "A7: Transfer Blocked - Identity restriction");

    _sendByDefaultTranches(msg.sender, _from, to, amount, data, operatorData);
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Empty function to erase ERC777 burn() function since it doesn't handle tranches.
   */
  function burn(uint256 /*amount*/, bytes /*data*/) external { // Comments to avoid compilation warnings for unused variables.
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Empty function to erase ERC777 operatorBurn() function since it doesn't handle tranches.
   */
  function operatorBurn(address /*from*/, uint256 /*amount*/, bytes /*data*/, bytes /*operatorData*/) external { // Comments to avoid compilation warnings for unused variables.
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Send tokens from default tranches.
   * @param operator The address performing the send.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder ('from') [can contain the destination tranche].
   * @param operatorData Information attached to the send by the operator.
   */
  function _sendByDefaultTranches(
    address operator,
    address from,
    address to,
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
        _sendByTranche(_defaultTranches[from][i], operator, from, to, _remainingAmount, data, operatorData);
        _remainingAmount = 0;
        break;
      } else {
        _sendByTranche(_defaultTranches[from][i], operator, from, to, _localBalance, data, operatorData);
        _remainingAmount = _remainingAmount - _localBalance;
      }
    }

    require(_remainingAmount == 0, "A8: Transfer Blocked - Token restriction");
  }
}
