/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./IERC1410.sol";
import "../ERC777/ERC777.sol";


contract ERC1410 is IERC1410, ERC777 {
  using SafeMath for uint256;

  /******************** Mappings to find tranche ******************************/
  // List of tranches
  bytes32[] internal _totalTranches;

  // Mapping from tranche to global balance of corresponding tranche
  mapping (bytes32 => uint256) internal _totalSupplyByTranche;

  // Mapping from investor to their tranches
  mapping (address => bytes32[]) internal _tranchesOf;

  // Mapping from (investor, tranche) to balance of corresponding tranche
  mapping (address => mapping (bytes32 => uint256)) internal _balanceOfByTranche;

  // Mapping from investor to their default tranches (for ERC777 and ERC20 backwards compatibility)
  mapping (address => bytes32[]) internal _defaultTranches;
  /****************************************************************************/



  /**************** Mappings to find operator by tranche **********************/
  // Mapping from (investor, tranche, operator) to 'approved for tranche' status [INVESTOR-SPECIFIC]
  mapping (address => mapping (bytes32 => mapping (address => bool))) internal _trancheAuthorized;

  // Mapping from (investor, tranche, operator) to 'revoked for tranche' status [INVESTOR-SPECIFIC]
  mapping (address => mapping (bytes32 => mapping (address => bool))) internal _trancheRevokedDefaultOperator;

  // Mapping from tranche to default operators for the tranche [NOT INVESTOR-SPECIFIC]
  mapping (bytes32 => address[]) internal _defaultOperatorsByTranche;

  // Mapping from (tranche, operator) to defaultOperatorByTranche status [NOT INVESTOR-SPECIFIC]
  mapping (bytes32 => mapping (address => bool)) internal _isDefaultOperatorByTranche;
  /****************************************************************************/

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


  /**
   * [ERC1410 INTERFACE (1/12)]
   * @dev View function that returns the balance of a tokenholder for a specific tranche
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which the balance is returned.
   */
  function balanceOfByTranche(bytes32 tranche, address tokenHolder) external view returns (uint256) {
    return _balanceOfByTranche[tokenHolder][tranche];
  }

  /**
   * [ERC1410 INTERFACE (2/12)]
   * @dev View function that returns the tranches index of a tokenholder
   * @param tokenHolder Address for which the tranches index are returned.
   */
  function tranchesOf(address tokenHolder) external view returns (bytes32[]) {
    return _tranchesOf[tokenHolder];
  }

  /**
   * [ERC1410 INTERFACE (3/12)]
   * @dev External function to send tokens from a specific tranche
   * @param tranche Name of the tranche.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
   * @return destination tranche.
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
   * @dev External function to send tokens from specific tranches
   * @param tranches Name of the tranches.
   * @param to Token recipient.
   * @param amounts Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
   * @return destination tranches.
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
    require(tranches.length == amounts.length);
    bytes32[] memory destinationTranches = new bytes32[](tranches.length);

    for (uint i = 0; i < tranches.length; i++) {
      destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, msg.sender, to, amounts[i], data, "");
    }

    return destinationTranches;
  }

  /**
   * [ERC1410 INTERFACE (5/12)]
   * @dev External function to send tokens from a specific tranche through an operator
   * @param tranche Name of the tranche.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [contains the destination tranche].
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   * @return destination tranche.
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
    returns (bytes32) // Return destination tranche
  {
    address _from = (from == address(0)) ? msg.sender : from;
    require(_isOperatorForTranche(tranche, msg.sender, _from));

    return _sendByTranche(tranche, msg.sender, _from, to, amount, data, operatorData);
  }

  /**
   * [ERC1410 INTERFACE (6/12)]
   * @dev External function to send tokens from specific tranches through an operator
   * @param tranches Name of the tranches.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amounts Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [contains the destination tranche].
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   * @return destination tranches.
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
    returns (bytes32[]) // Return destination tranches
  {
    require(tranches.length == amounts.length);
    bytes32[] memory destinationTranches = new bytes32[](tranches.length);
    address _from = (from == address(0)) ? msg.sender : from;

    for (uint i = 0; i < tranches.length; i++) {
      require(_isOperatorForTranche(tranches[i], msg.sender, _from));

      destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, from, to, amounts[i], data, operatorData);
    }

    return destinationTranches;
  }

  /**
   * [ERC1410 INTERFACE (7/12)][OPTIONAL]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev View function to get default tranches to send from.
   *  For example, a security token may return the bytes32("unrestricted").
   * @param tokenHolder Address for which we want to know the default tranches.
   */
  function getDefaultTranches(address tokenHolder) external view returns (bytes32[]) {
    return _defaultTranches[tokenHolder];
  }

  /**
   * [ERC1410 INTERFACE (8/12)][OPTIONAL]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev External function to set default tranches to send from.
   * @param tranches tranches to use by default when not specified.
   */
  function setDefaultTranches(bytes32[] tranches) external {
    _defaultTranches[msg.sender] = tranches;
  }

  /**
   * [ERC1410 INTERFACE (9/12)]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev External function to get default operators for a given tranche.
   * @param tranche Name of the tranche.
   */
  function defaultOperatorsByTranche(bytes32 tranche) external view returns (address[]) {
    return _defaultOperatorsByTranche[tranche];
  }

  /**
   * [ERC1410 INTERFACE (10/12)]
   * @dev External function to set as an operator for msg.sender for a given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address to set as an operator for msg.sender.
   */
  function authorizeOperatorByTranche(bytes32 tranche, address operator) external {
    _trancheRevokedDefaultOperator[msg.sender][tranche][operator] = false;
    _trancheAuthorized[msg.sender][tranche][operator] = true;
    emit AuthorizedOperatorByTranche(tranche, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (11/12)]
   * @dev External function to remove the right of the operator address to be an operator
   *  on a given tranche for msg.sender and to send and burn tokens on its behalf.
   * @param tranche Name of the tranche.
   * @param operator Address to rescind as an operator on given tranche for msg.sender.
   */
  function revokeOperatorByTranche(bytes32 tranche, address operator) external {
    _trancheRevokedDefaultOperator[msg.sender][tranche][operator] = true;
    _trancheAuthorized[msg.sender][tranche][operator] = false;
    emit RevokedOperatorByTranche(tranche, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (12/12)]
   * @dev External function to indicate whether the operator address is an operator
   *  of the tokenHolder address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   */
  function isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorForTranche(tranche, operator, tokenHolder);
  }

  /**
   * @dev Internal function to indicate whether the operator address is an operator
   *  of the tokenHolder address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   */
  function _isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) internal view returns (bool) {
    return (operator == tokenHolder
      || _isOperatorFor(operator, tokenHolder)
      || _trancheAuthorized[tokenHolder][tranche][operator]
      || (_isDefaultOperatorByTranche[tranche][operator] && !_trancheRevokedDefaultOperator[tokenHolder][tranche][operator])
    );
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Internal function to add a default operator for the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function _addDefaultOperatorByTranche(bytes32 tranche, address operator) internal {
    require(!_isDefaultOperatorByTranche[tranche][operator]);
    _defaultOperatorsByTranche[tranche].push(operator);
    _isDefaultOperatorByTranche[tranche][operator] = true;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Internal function to add a default operator for the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function _removeDefaultOperatorByTranche(bytes32 tranche, address operator) internal {
    require(_isDefaultOperatorByTranche[tranche][operator]);

    for (uint i = 0; i<_defaultOperatorsByTranche[tranche].length; i++){
      if(_defaultOperatorsByTranche[tranche][i] == operator) {
        _defaultOperatorsByTranche[tranche][i] = _defaultOperatorsByTranche[tranche][_defaultOperatorsByTranche[tranche].length - 1];
        delete _defaultOperatorsByTranche[tranche][_defaultOperatorsByTranche[tranche].length-1];
        _defaultOperatorsByTranche[tranche].length--;
        break;
      }
    }
    _isDefaultOperatorByTranche[tranche][operator] = false;
  }

  /**
   * @dev Internal function to send tokens from a specific tranche
   * @param fromTranche Tranche of the tokens to send.
   * @param operator The address performing the send.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [can contain the destination tranche].
   * @param operatorData Information attached to the send by the operator.
   * @return destination tranche.
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
    require(_balanceOfByTranche[from][fromTranche] >= amount); // ensure enough funds

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
   * @dev Internal function to remove a token from a tranche
   * @param from Token holder.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   */
  function _removeTokenFromTranche(address from, bytes32 tranche, uint256 amount) internal {
    _balanceOfByTranche[from][tranche] = _balanceOfByTranche[from][tranche].sub(amount);
    _totalSupplyByTranche[tranche] = _totalSupplyByTranche[tranche].sub(amount);

    if(_balanceOfByTranche[from][tranche] == 0) {
      for (uint i = 0; i < _tranchesOf[from].length; i++) {
        if(_tranchesOf[from][i] == tranche) {
          _tranchesOf[from][i] = _tranchesOf[from][_tranchesOf[from].length - 1];
          delete _tranchesOf[from][_tranchesOf[from].length - 1];
          _tranchesOf[from].length--;
        }
      }
    }
    if(_totalSupplyByTranche[tranche] == 0) {
      for (i = 0; i < _totalTranches.length; i++) {
        if(_totalTranches[i] == tranche) {
          _totalTranches[i] = _totalTranches[_totalTranches.length - 1];
          delete _totalTranches[_totalTranches.length - 1];
          _totalTranches.length--;
        }
      }
    }
  }

  /**
   * @dev Internal function to add a token to a tranche
   * @param to Token recipient.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   */
  function _addTokenToTranche(address to, bytes32 tranche, uint256 amount) internal {
    if(_balanceOfByTranche[to][tranche] == 0 && amount != 0) {
      _tranchesOf[to].push(tranche);
    }
    _balanceOfByTranche[to][tranche] = _balanceOfByTranche[to][tranche].add(amount);

    if(_totalSupplyByTranche[tranche] == 0 && amount != 0) {
      _totalTranches.push(tranche);
    }
    _totalSupplyByTranche[tranche] = _totalSupplyByTranche[tranche].add(amount);
  }

  /**
   * @dev Internal function to retrieve the destination tranche from the 'data' field.
   *  Basically, this function only converts the bytes variable into a bytes32 variable.
   * @param data Information attached to the send [contains the destination tranche].
   */
  function _getDestinationTranche(bytes data) internal pure returns(bytes32) {
    bytes32 toTranche;
    for (uint i = 0; i < 32; i++) {
      toTranche |= bytes32(data[i] & 0xFF) >> (i * 8); // Keeps the 8 first bits of data[i] and shifts them from (i * 8 places)
    }
    return toTranche;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Send the amount of tokens from the address msg.sender to the address to.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
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
   * @param from Token holder (or address(0) to set from to msg.sender).
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [can contain the destination tranche].
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   */
  function operatorSendTo(address from, address to, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from));

    _sendByDefaultTranches(msg.sender, _from, to, amount, data, operatorData);
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Transfer token for a specified address
   * @param to The address to transfer to.
   * @param value The amount to be transferred.
   */
  function transfer(address to, uint256 value) external returns (bool) {
    require(_erc20compatible);

    _sendByDefaultTranches(msg.sender, msg.sender, to, value, "", "");

    return true;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Transfer tokens from one address to another
   * @param from The address which you want to send tokens from
   * @param to The address which you want to transfer to
   * @param value The amount of tokens to be transferred
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  )
    external
    returns (bool)
  {
    require(_erc20compatible);

    address _from = (from == address(0)) ? msg.sender : from;
    require( _isOperatorFor(msg.sender, _from)
      || (value <= _allowed[_from][msg.sender])
    );

    if(_allowed[_from][msg.sender] >= value) {
      _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(value);
    } else {
      _allowed[_from][msg.sender] = 0;
    }

    _sendByDefaultTranches(msg.sender, _from, to, value, "", "");
    return true;
  }

  /**
  * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Internal function to send tokens from a default tranches
   * @param operator The address performing the send.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [can contain the destination tranche].
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
    uint256 _remainingAmount = amount;
    uint256 _localBalance;

    require(_defaultTranches[from].length != 0);

    if(_defaultTranches[from].length != 0) {
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
    }

    require(_remainingAmount == 0);
  }

}
