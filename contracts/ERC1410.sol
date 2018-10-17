/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./IERC1410.sol";
import "./token/ERC820/ERC820Client.sol";
import "./token/ERC777/ERC777.sol";
/* import "./ERC777TokensSender.sol";
import "./ERC777TokensRecipient.sol"; */


contract ERC1410 is IERC1410, ERC820Client, ERC777 {
  using SafeMath for uint256;

  /* string internal _name; --> ERC777 */
  /* string internal _symbol; --> ERC777 */
  /* uint256 internal _granularity; --> ERC777 */
  /* uint256 internal _totalSupply; --> ERC777 */

  /* mapping(address => uint256) internal _balances; --> ERC777 */
  /* Mapping from (investor, operator) to approved status (can be used against any tranches) */
  /* mapping(address => mapping(address => bool)) internal _authorized; --> ERC777 */

  /* address[] internal _defaultOperators; --> ERC777 */
  /* mapping(address => bool) internal _isDefaultOperator; --> ERC777 */
  /* mapping(address => mapping(address => bool)) internal _revokedDefaultOperator; --> ERC777 */

  struct Tranche {
    uint256 amount;
    bytes32 tranche;
  }

  // Mapping from investor to their tranches
  mapping (address => Tranche[]) _tranches;

  // Mapping from (investor, tranche) to index of corresponding tranche in _tranches
  mapping (address => mapping (bytes32 => uint256)) _trancheToIndex;

  // Mapping from investor to their default tranches (for ERC777 and ERC20 backwards compatibility)
  mapping (address => bytes32[]) _defaultTranches;

  // Mapping from (investor, tranche, operator) to 'approved for tranche' status
  mapping (address => mapping (bytes32 => mapping (address => bool))) _trancheAuthorized;

  // Mapping from tranche to list of tranche approved operators
  mapping (bytes32 => address[]) _defaultOperators;

  /**
   * @dev Throws if xxx
   */
  modifier canSendFromTranche(bytes32 tranche, address from, address to, uint256 amount, bytes data) {
    require(balanceOfByTranche(tranche, from) >= amount); // ensure enough funds
    require(_canSendDataFromTranche(tranche, from, to, amount, data));
    _;
  }

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators
    )
    public
    ERC777(name, symbol, granularity, defaultOperators)
    {
      setInterfaceImplementation("ERC1410Token", this);
    }

    function balanceOfByTranche(bytes32 tranche, address tokenHolder) public view returns (uint256) {
      return _tranches[tokenHolder][_trancheToIndex[tokenHolder][tranche]].amount;
    }

    function tranchesOf(address tokenHolder) external view returns (bytes32[]) {
      bytes32[] memory tranches = new bytes32[](_tranches[tokenHolder].length);
      for (uint i = 0; i < _tranches[tokenHolder].length; i++) {
        tranches[i] = _tranches[tokenHolder][i].tranche;
      }
      return tranches;
    }

    function sendByTranche(
      bytes32 tranche,
      address to,
      uint256 amount,
      bytes data
    )
      external
      returns (bytes32)
    {
      return _sendByTranche(tranche, msg.sender, msg.sender, to, amount, data, "");
    }

    function sendByTranches(
      bytes32[] tranches,
      address to,
      uint256[] amounts,
      bytes data
    )
      external
      returns (bytes32[])
    {
      require(tranches.length == amounts.length);
      bytes32[] memory destinationTranches = new bytes32[](tranches.length);

      for (uint i = 0; i < tranches.length; i++) {
        destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, msg.sender, to, amounts[i], data, "");
      }

      return destinationTranches;
    }

    function operatorSendByTranche(
      bytes32 tranche,
      address from,
      address to,
      uint256 amount,
      bytes data,
      bytes operatorData
    )
      external
      returns (bytes32) // Return destination tranche
    {
      require(isOperatorForTranche(tranche, msg.sender, from));

      return _sendByTranche(tranche, msg.sender, from, to, amount, data, operatorData);
    }

    function operatorSendByTranches(
      bytes32[] tranches,
      address from,
      address to,
      uint256[] amounts,
      bytes data,
      bytes operatorData
    )
      external
      returns (bytes32[]) // Return destination tranches
    {
      require(tranches.length == amounts.length);
      bytes32[] memory destinationTranches = new bytes32[](tranches.length);

      for (uint i = 0; i < tranches.length; i++) {
        require(isOperatorForTranche(tranches[i], msg.sender, from));

        destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, from, to, amounts[i], data, operatorData);
      }

      return destinationTranches;
    }

    // For ERC777 and ERC20 backwards compatibility
    function getDefaultTranches(address tokenHolder) external view returns (bytes32[]) {
      return _defaultTranches[tokenHolder];
    }

    // For ERC777 and ERC20 backwards compatibility
    function setDefaultTranche(bytes32[] tranches) external {
      //TODO: fix compile error - _defaultTranches[tokenHolder] = tranches;
    }

    // USELESS - NO METHOD TO SET OPERATORS BY TRANCHE
    function defaultOperatorsByTranche(bytes32 tranche) external view returns (address[]) {
      return _defaultOperators[tranche];
    }

    function authorizeOperatorByTranche(bytes32 tranche, address operator) external {
      _trancheAuthorized[msg.sender][tranche][operator] = true;
      emit AuthorizedOperatorByTranche(tranche, operator, msg.sender);
    }

    function revokeOperatorByTranche(bytes32 tranche, address operator) external {
      _trancheAuthorized[msg.sender][tranche][operator] = false;
      emit RevokedOperatorByTranche(tranche, operator, msg.sender);
    }

    function isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) public view returns (bool) {
      return _trancheAuthorized[tokenHolder][tranche][operator];
    }

    /**
     * @dev Internal xxx
     * @param xxx
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
      canSendFromTranche(fromTranche, from, to, amount, data)
      returns (bytes32)
    {
      bytes32 toTranche = _getDestinationTranche(fromTranche, from, to, amount, data);

      _removeTokenFromTranche(from, fromTranche, amount);
      //TODO: fix compile error - operatorSendByTranche(fromTranche, from, to, amount, data, operatorData);
      _addTokenToTranche(to, toTranche, amount);

      emit SentByTranche(fromTranche, operator, from, to, amount, data, operatorData);

      if(toTranche != fromTranche) {
        emit ChangedTranche(fromTranche, toTranche, amount);
      }

      return toTranche;
    }

  /**
   * @dev Internal xxx
   * @param xxx
   */
  function _removeTokenFromTranche(address from, bytes32 tranche, uint256 amount) internal {
    _tranches[from][_trancheToIndex[from][tranche]].amount =
    _tranches[from][_trancheToIndex[from][tranche]].amount.sub(amount);
  }

  /**
   * @dev Internal xxx
   * @param xxx
   */
   function _addTokenToTranche(address to, bytes32 tranche, uint256 amount) internal {
     if(!_trancheExists(to, tranche)) {
       _createTranche(to, tranche);
     }
     _tranches[to][_trancheToIndex[to][tranche]].amount =
     _tranches[to][_trancheToIndex[to][tranche]].amount.add(amount);
   }

   /**
    * @dev Internal xxx
    * @param xxx
    */
   function _trancheExists(address to, bytes32 tranche) internal view returns(bool) {
     return _tranches[to][_trancheToIndex[to][tranche]].tranche != bytes32(0);
   }

   /**
    * @dev Internal xxx
    * @param xxx
    */
    function _createTranche(address to, bytes32 tranche) internal returns(bool) {
      require(tranche != bytes32(0)); // Required to be able to check if tranche exists
      _tranches[to].push(Tranche(
        0,
        tranche
      ));
      _trancheToIndex[to][tranche] = _tranches[to].length.sub(1);
      return true;
    }

  /***************************/
  /* METHOD TO BE EXPORTED IN AN SEPARATE CONTRACT TO BE UPGRADEABLE */
  /***************************/
  function _canSendDataFromTranche(
    bytes32 tranche,
    address from,
    address to,
    uint256 amount,
    bytes data
  ) internal returns(bool) {
    // METHOD TO OVERWRITE TO INJECT BUSINESS LOGIC
    return true;
  }

  /***************************/
  /* METHOD TO BE EXPORTED IN AN SEPARATE CONTRACT TO BE UPGRADEABLE */
  /***************************/
  function _getDestinationTranche(
    bytes32 fromTranche,
    address from,
    address to,
    uint256 amount,
    bytes data
  )
    internal
    returns(bytes32)
  {
    /***************************/
    bytes32 toTranche = fromTranche; // METHOD TO BE OVERWRITEN TO INJECT BUSINESS LOGIC
    /***************************/

    return toTranche;
  }

}
