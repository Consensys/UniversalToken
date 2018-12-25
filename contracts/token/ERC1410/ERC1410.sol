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

  /******************** Mappings to find partition ******************************/
  // List of partitions.
  bytes32[] internal _totalPartitions;

  // Mapping from partition to global balance of corresponding partition.
  mapping (bytes32 => uint256) internal _totalSupplyByPartition;

  // Mapping from tokenHolder to their partitions.
  mapping (address => bytes32[]) internal _partitionsOf;

  // Mapping from (tokenHolder, partition) to balance of corresponding partition.
  mapping (address => mapping (bytes32 => uint256)) internal _balanceOfByPartition;

  // Mapping from tokenHolder to their default partitions (for ERC777 and ERC20 compatibility).
  mapping (address => bytes32[]) internal _defaultPartitionsOf;

  // List of token default partitions (for ERC20 compatibility).
  bytes32[] internal _tokenDefaultPartitions;
  /****************************************************************************/

  /**************** Mappings to find partition operators ************************/
  // Mapping from (tokenHolder, partition, operator) to 'approved for partition' status. [TOKEN-HOLDER-SPECIFIC]
  mapping (address => mapping (bytes32 => mapping (address => bool))) internal _partitionAuthorizedOperator;

  // Mapping from partition to controllers for the partition. [NOT TOKEN-HOLDER-SPECIFIC]
  mapping (bytes32 => address[]) internal _partitionControllers;

  // Mapping from (partition, operator) to controllerByPartition status. [NOT TOKEN-HOLDER-SPECIFIC]
  mapping (bytes32 => mapping (address => bool)) internal _isPartitionController;
  /****************************************************************************/

  /**
   * [ERC1410 CONSTRUCTOR]
   * @dev Initialize ERC1410 parameters + register
   * the contract implementation in ERC820Registry.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, mint,
   * burn (Cf. CertificateController.sol).
   */
  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner,
    bytes32[] tokenDefaultPartitions
  )
    public
    ERC777(name, symbol, granularity, controllers, certificateSigner)
  {
    setInterfaceImplementation("ERC1410Token", this);
    _tokenDefaultPartitions = tokenDefaultPartitions;
  }

  /********************** ERC1410 EXTERNAL FUNCTIONS **************************/

  /**
   * [ERC1410 INTERFACE (1/10)]
   * @dev Get balance of a tokenholder for a specific partition.
   * @param partition Name of the partition.
   * @param tokenHolder Address for which the balance is returned.
   * @return Amount of token of partition 'partition' held by 'tokenHolder' in the token contract.
   */
  function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256) {
    return _balanceOfByPartition[tokenHolder][partition];
  }

  /**
   * [ERC1410 INTERFACE (2/10)]
   * @dev Get partitions index of a tokenholder.
   * @param tokenHolder Address for which the partitions index are returned.
   * @return Array of partitions index of 'tokenHolder'.
   */
  function partitionsOf(address tokenHolder) external view returns (bytes32[]) {
    return _partitionsOf[tokenHolder];
  }

  /**
   * [ERC1410 INTERFACE (3/10)]
   * @dev Transfer tokens from a specific partition.
   * @param partition Name of the partition.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return Destination partition.
   */
  function transferByPartition(
    bytes32 partition,
    address to,
    uint256 value,
    bytes data
  )
    external
    isValidCertificate(data)
    returns (bytes32)
  {
    return _transferByPartition(partition, msg.sender, msg.sender, to, value, data, "");
  }

  /**
   * [ERC1410 INTERFACE (4/10)]
   * @dev Transfer tokens from a specific partition through an operator.
   * @param partition Name of the partition.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, and intended for the token holder ('from'). [Contains the destination partition]
   * @param operatorData Information attached to the transfer by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return Destination partition.
   */
  function operatorTransferByPartition(
    bytes32 partition,
    address from,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    external
    isValidCertificate(operatorData)
    returns (bytes32)
  {
    address _from = (from == address(0)) ? msg.sender : from;
    require(_isOperatorForPartition(partition, msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    return _transferByPartition(partition, msg.sender, _from, to, value, data, operatorData);
  }

  /**
   * [ERC1410 INTERFACE (5/10)]
   * @dev Get default partitions to transfer from.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * For example, a security token may return the bytes32("unrestricted").
   * @param tokenHolder Address for which we want to know the default partitions.
   * @return Array of default partitions.
   */
  function getDefaultPartitions(address tokenHolder) external view returns (bytes32[]) {
    return _defaultPartitionsOf[tokenHolder];
  }

  /**
   * [ERC1410 INTERFACE (6/10)]
   * @dev Set default partitions to transfer from.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * @param partitions partitions to use by default when not specified.
   */
  function setDefaultPartitions(bytes32[] partitions) external {
    _defaultPartitionsOf[msg.sender] = partitions;
  }

  /**
   * [ERC1410 INTERFACE (7/10)]
   * @dev Get controllers for a given partition.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * @param partition Name of the partition.
   * @return Array of controllers for partition.
   */
  function controllersByPartition(bytes32 partition) external view returns (address[]) {
    return _partitionControllers[partition];
  }

  /**
   * [ERC1410 INTERFACE (8/10)]
   * @dev Set 'operator' as an operator for 'msg.sender' for a given partition.
   * @param partition Name of the partition.
   * @param operator Address to set as an operator for 'msg.sender'.
   */
  function authorizeOperatorByPartition(bytes32 partition, address operator) external {
    _partitionAuthorizedOperator[msg.sender][partition][operator] = true;
    emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (9/10)]
   * @dev Remove the right of the operator address to be an operator on a given
   * partition for 'msg.sender' and to transfer and burn tokens on its behalf.
   * @param partition Name of the partition.
   * @param operator Address to rescind as an operator on given partition for 'msg.sender'.
   */
  function revokeOperatorByPartition(bytes32 partition, address operator) external {
    _partitionAuthorizedOperator[msg.sender][partition][operator] = false;
    emit RevokedOperatorByPartition(partition, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (10/10)]
   * @dev Indicate whether the operator address is an operator of the tokenHolder
   * address for the given partition.
   * @param partition Name of the partition.
   * @param operator Address which may be an operator of tokenHolder for the given partition.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given partition.
   * @return 'true' if 'operator' is an operator of 'tokenHolder' for partition 'partition' and 'false' otherwise.
   */
  function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorForPartition(partition, operator, tokenHolder);
  }

  /********************** ERC1410 INTERNAL FUNCTIONS **************************/

  /**
   * [INTERNAL]
   * @dev Indicate whether the operator address is an operator of the tokenHolder
   * address for the given partition.
   * @param partition Name of the partition.
   * @param operator Address which may be an operator of tokenHolder for the given partition.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given partition.
   * @return 'true' if 'operator' is an operator of 'tokenHolder' for partition 'partition' and 'false' otherwise.
   */
   function _isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) internal view returns (bool) {
     return (_isOperatorFor(operator, tokenHolder)
       || _partitionAuthorizedOperator[tokenHolder][partition][operator]
       || (_isControllable && _isPartitionController[partition][operator])
     );
   }

  /**
   * [INTERNAL]
   * @dev Transfer tokens from a specific partition.
   * @param fromPartition Partition of the tokens to transfer.
   * @param operator The address performing the transfer.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, and intended for the token holder ('from'). [Can contain the destination partition]
   * @param operatorData Information attached to the transfer by the operator.
   * @return Destination partition.
   */
  function _transferByPartition(
    bytes32 fromPartition,
    address operator,
    address from,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    internal
    returns (bytes32)
  {
    require(_balanceOfByPartition[from][fromPartition] >= value, "A4: Transfer Blocked - Sender balance insufficient"); // ensure enough funds

    bytes32 toPartition = fromPartition;
    if(operatorData.length != 0 && data.length != 0) {
      toPartition = _getDestinationPartition(data);
    }

    _removeTokenFromPartition(from, fromPartition, value);
    _transferWithData(operator, from, to, value, data, operatorData, true);
    _addTokenToPartition(to, toPartition, value);

    emit TransferByPartition(fromPartition, operator, from, to, value, data, operatorData);

    if(toPartition != fromPartition) {
      emit ChangedPartition(fromPartition, toPartition, value);
    }

    return toPartition;
  }

  /**
   * [INTERNAL]
   * @dev Remove a token from a specific partition.
   * @param from Token holder.
   * @param partition Name of the partition.
   * @param value Number of tokens to transfer.
   */
  function _removeTokenFromPartition(address from, bytes32 partition, uint256 value) internal {
    _balanceOfByPartition[from][partition] = _balanceOfByPartition[from][partition].sub(value);
    _totalSupplyByPartition[partition] = _totalSupplyByPartition[partition].sub(value);

    // If the balance of the TokenHolder's partition is zero, finds and deletes the partition.
    if(_balanceOfByPartition[from][partition] == 0) {
      for (uint i = 0; i < _partitionsOf[from].length; i++) {
        if(_partitionsOf[from][i] == partition) {
          _partitionsOf[from][i] = _partitionsOf[from][_partitionsOf[from].length - 1];
          delete _partitionsOf[from][_partitionsOf[from].length - 1];
          _partitionsOf[from].length--;
          break;
        }
      }
    }

    // If the total supply is zero, finds and deletes the partition.
    if(_totalSupplyByPartition[partition] == 0) {
      for (i = 0; i < _totalPartitions.length; i++) {
        if(_totalPartitions[i] == partition) {
          _totalPartitions[i] = _totalPartitions[_totalPartitions.length - 1];
          delete _totalPartitions[_totalPartitions.length - 1];
          _totalPartitions.length--;
          break;
        }
      }
    }
  }

  /**
   * [INTERNAL]
   * @dev Add a token to a specific partition.
   * @param to Token recipient.
   * @param partition Name of the partition.
   * @param value Number of tokens to transfer.
   */
  function _addTokenToPartition(address to, bytes32 partition, uint256 value) internal {
    if(value != 0) {
      if(_balanceOfByPartition[to][partition] == 0) {
        _partitionsOf[to].push(partition);
      }
      _balanceOfByPartition[to][partition] = _balanceOfByPartition[to][partition].add(value);

      if(_totalSupplyByPartition[partition] == 0) {
        _totalPartitions.push(partition);
      }
      _totalSupplyByPartition[partition] = _totalSupplyByPartition[partition].add(value);
    }
  }

  /**
   * [INTERNAL]
   * @dev Retrieve the destination partition from the 'data' field.
   * Basically, this function only converts the bytes variable into a bytes32 variable.
   * @param data Information attached to the transfer [Contains the destination partition].
   * @return Destination partition.
   */
  function _getDestinationPartition(bytes data) internal pure returns(bytes32 toPartition) {
    assembly {
      toPartition := mload(add(data, 32))
    }
  }

  /**
   * [INTERNAL]
   * @dev Get the sender's default partition if setup, or the global default partition if not.
   * @param tokenHolder Address for which the default partition is returned.
   * @return Default partition.
   */
  function _getDefaultPartitions(address tokenHolder) internal view returns(bytes32[]) {
    if(_defaultPartitionsOf[tokenHolder].length != 0) {
      return _defaultPartitionsOf[tokenHolder];
    } else {
      return _tokenDefaultPartitions;
    }
  }


  /********************* ERC1410 OPTIONAL FUNCTIONS ***************************/

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Get list of existing partitions.
   * @return Array of all exisiting partitions.
   */
  function totalPartitions() external view returns (bytes32[]) {
    return _totalPartitions;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Add a controller for a specific partition of the token.
   * @param partition Name of the partition.
   * @param operator Address to set as a controller.
   */
  function _addControllerByPartition(bytes32 partition, address operator) internal {
    require(!_isPartitionController[partition][operator], "Action Blocked - Already a controller");
    _partitionControllers[partition].push(operator);
    _isPartitionController[partition][operator] = true;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Remove controller of a specific partition of the token.
   * @param partition Name of the partition.
   * @param operator Address to remove from controllers of partition.
   */
  function _removeControllerByPartition(bytes32 partition, address operator) internal {
    require(_isPartitionController[partition][operator], "Action Blocked - Not a controller");

    for (uint i = 0; i < _partitionControllers[partition].length; i++){
      if(_partitionControllers[partition][i] == operator) {
        _partitionControllers[partition][i] = _partitionControllers[partition][_partitionControllers[partition].length - 1];
        delete _partitionControllers[partition][_partitionControllers[partition].length-1];
        _partitionControllers[partition].length--;
        break;
      }
    }
    _isPartitionController[partition][operator] = false;
  }

  /************** ERC777 BACKWARDS RETROCOMPATIBILITY *************************/

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Transfer the value of tokens from the address 'msg.sender' to the address 'to'.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function transferWithData(address to, uint256 value, bytes data)
    external
    isValidCertificate(data)
  {
    _transferByDefaultPartitions(msg.sender, msg.sender, to, value, data, "");
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Transfer the value of tokens on behalf of the address from to the address to.
   * @param from Token holder (or 'address(0)'' to set from to 'msg.sender').
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, and intended for the token holder ('from'). [Can contain the destination partition]
   * @param operatorData Information attached to the transfer by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function transferFromWithData(address from, address to, uint256 value, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    _transferByDefaultPartitions(msg.sender, _from, to, value, data, operatorData);
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Empty function to erase ERC777 burn() function since it doesn't handle partitions.
   */
  function burn(uint256 /*value*/, bytes /*data*/) external { // Comments to avoid compilation warnings for unused variables.
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Empty function to erase ERC777 operatorBurn() function since it doesn't handle partitions.
   */
  function operatorBurn(address /*from*/, uint256 /*value*/, bytes /*data*/, bytes /*operatorData*/) external { // Comments to avoid compilation warnings for unused variables.
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Transfer tokens from default partitions.
   * @param operator The address performing the transfer.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, and intended for the token holder ('from') [can contain the destination partition].
   * @param operatorData Information attached to the transfer by the operator.
   */
  function _transferByDefaultPartitions(
    address operator,
    address from,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    internal
  {
    bytes32[] memory _partitions = _getDefaultPartitions(from);
    require(_partitions.length != 0, "A8: Transfer Blocked - Token restriction");

    uint256 _remainingValue = value;
    uint256 _localBalance;

    for (uint i = 0; i < _partitions.length; i++) {
      _localBalance = _balanceOfByPartition[from][_partitions[i]];
      if(_remainingValue <= _localBalance) {
        _transferByPartition(_partitions[i], operator, from, to, _remainingValue, data, operatorData);
        _remainingValue = 0;
        break;
      } else {
        _transferByPartition(_partitions[i], operator, from, to, _localBalance, data, operatorData);
        _remainingValue = _remainingValue - _localBalance;
      }
    }

    require(_remainingValue == 0, "A8: Transfer Blocked - Token restriction");
  }
}
