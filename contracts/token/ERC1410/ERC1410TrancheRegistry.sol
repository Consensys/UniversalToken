/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";


contract ERC1410TrancheRegistry is Secondary {
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


  /**
   * [ERC1410TrancheRegistry INTERFACE (1/15)]
   * @dev View function that returns an array of all exisiting tranches
   */
  function totalTranches() external view onlyPrimary returns (bytes32[]) {
    return _totalTranches;
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (2/15)]
   * @dev View function that returns the balance of a tokenholder for a specific tranche
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which the balance is returned.
   */
  function balanceOfByTranche(bytes32 tranche, address tokenHolder) external view onlyPrimary returns (uint256) {
    return _balanceOfByTranche[tokenHolder][tranche];
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (3/15)]
   * @dev View function that returns the tranches index of a tokenholder
   * @param tokenHolder Address for which the tranches index are returned.
   */
  function tranchesOf(address tokenHolder) external view onlyPrimary returns (bytes32[]) {
    return _tranchesOf[tokenHolder];
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (4/15)]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev View function to get default tranches to send from.
   *  For example, a security token may return the bytes32("unrestricted").
   * @param tokenHolder Address for which we want to know the default tranches.
   */
  function getDefaultTranches(address tokenHolder) external view onlyPrimary returns (bytes32[]) {
    return _defaultTranches[tokenHolder];
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (5/15)]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev External function to set default tranches to send from.
   * @param tranches tranches to use by default when not specified.
   */
  function setDefaultTranches(bytes32[] tranches) external onlyPrimary {
    _defaultTranches[msg.sender] = tranches;
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (6/15)]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev External function to get default operators for a given tranche.
   * @param tranche Name of the tranche.
   */
  function defaultOperatorsByTranche(bytes32 tranche) external view onlyPrimary returns (address[]) {
    return _defaultOperatorsByTranche[tranche];
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (7/15)]
   * @dev External function to set as an operator for msg.sender for a given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address to set as an operator for msg.sender.
   */
  function authorizeOperatorByTranche(bytes32 tranche, address operator) external onlyPrimary {
    _trancheRevokedDefaultOperator[msg.sender][tranche][operator] = false;
    _trancheAuthorized[msg.sender][tranche][operator] = true;
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (8/15)]
   * @dev External function to remove the right of the operator address to be an operator
   *  on a given tranche for msg.sender and to send and burn tokens on its behalf.
   * @param tranche Name of the tranche.
   * @param operator Address to rescind as an operator on given tranche for msg.sender.
   */
  function revokeOperatorByTranche(bytes32 tranche, address operator) external onlyPrimary {
    _trancheRevokedDefaultOperator[msg.sender][tranche][operator] = true;
    _trancheAuthorized[msg.sender][tranche][operator] = false;
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (9/15)]
   * @dev External function to indicate whether the operator address is an operator
   *  of the tokenHolder address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   * @param isControllable 'true' of the token is controllable e.g. if the default operator can not be revoked.
   */
  function isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder, bool isControllable) external view onlyPrimary returns (bool) {
    return (_trancheAuthorized[tokenHolder][tranche][operator]
      || (_isDefaultOperatorByTranche[tranche][operator] && !_trancheRevokedDefaultOperator[tokenHolder][tranche][operator])
      || (_isDefaultOperatorByTranche[tranche][operator] && isControllable)
    );
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (10/15)]
   * @dev External function to retrieve the destination tranche from the 'data' field.
   *  Basically, this function only converts the bytes variable into a bytes32 variable.
   * @param data Information attached to the send [contains the destination tranche].
   */
  function getDestinationTranche(bytes data) external onlyPrimary returns(bytes32) {
    bytes32 toTranche;
    for (uint i = 0; i < 32; i++) {
      toTranche |= bytes32(data[i] & 0xFF) >> (i * 8); // Keeps the 8 first bits of data[i] and shifts them from (i * 8 places)
    }
    return toTranche;
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (11/15)]
   * @dev External function to add a default operator for the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function addDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyPrimary {
    require(!_isDefaultOperatorByTranche[tranche][operator]);
    _defaultOperatorsByTranche[tranche].push(operator);
    _isDefaultOperatorByTranche[tranche][operator] = true;
  }

  /**
   * [ERC1410TrancheRegistry INTERFACE (12/15)]
   * @dev External function to add a default operator for the token.
   * @param tranche Name of the tranche.
   * @param operator Address to set as a default operator.
   */
  function removeDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyPrimary {
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
   * [ERC1410TrancheRegistry INTERFACE (13/15)]
   * @dev External function to remove a token from a tranche
   * @param from Token holder.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   */
  function removeTokenFromTranche(address from, bytes32 tranche, uint256 amount) external onlyPrimary {
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
   * [ERC1410TrancheRegistry INTERFACE (14/15)]
   * @dev External function to add a token to a tranche
   * @param to Token recipient.
   * @param tranche Name of the tranche.
   * @param amount Number of tokens to send.
   */
  function addTokenToTranche(address to, bytes32 tranche, uint256 amount) external onlyPrimary {
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
   * [ERC1410TrancheRegistry INTERFACE (15/15)]
   * @dev External function to add a token to a tranche
   * @param tokenHolder Address for which the default tranches corresponding to amount are returned.
   * @param amount Number of tokens to search for in tranches.
   */
  function getDefaultTranchesForAmount(address tokenHolder, uint256 amount) external  view onlyPrimary returns(bytes32[] _tranches, uint256[] _amounts) {
    uint256 _remainingAmount = amount;
    uint256 _localBalance;

    if(_defaultTranches[tokenHolder].length != 0) {
      for (uint i = 0; i < _defaultTranches[tokenHolder].length; i++) {
        _localBalance = _balanceOfByTranche[tokenHolder][_defaultTranches[tokenHolder][i]];
        if(_remainingAmount <= _localBalance) {
          _tranches[i] = _defaultTranches[tokenHolder][i];
          _amounts[i] = _remainingAmount;
          _remainingAmount = 0;
          break;
        } else {
          _tranches[i] = _defaultTranches[tokenHolder][i];
          _amounts[i] = _localBalance;
          _remainingAmount = _remainingAmount - _localBalance;
        }
      }
    }

    require(_remainingAmount == 0);

    return (_tranches, _amounts);
  }

}
