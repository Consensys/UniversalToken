/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

/**
 * @title IERC1410 partially fungible token standard
 * @dev ERC1410 interface
 */
interface IERC1410 {

    // Token Information
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256); // 1/12
    function partitionsOf(address tokenHolder) external view returns (bytes32[]); // 2/12

    // Token Transfers
    function transferByPartition(bytes32 partition, address to, uint256 amount, bytes data) external returns (bytes32); // 3/12
    function transferByPartitions(bytes32[] partitions, address to, uint256[] amounts, bytes data) external returns (bytes32[]); // 4/12
    function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 amount, bytes data, bytes operatorData) external returns (bytes32); // 5/12
    function operatorTransferByPartitions(bytes32[] partitions, address from, address to, uint256[] amounts, bytes data, bytes operatorData) external returns (bytes32[]); // 6/12

    // Default Partition Management
    function getDefaultPartitions(address tokenHolder) external view returns (bytes32[]); // 7/12
    function setDefaultPartitions(bytes32[] partitions) external; // 8/12

    // Operators
    function defaultOperatorsByPartition(bytes32 partition) external view returns (address[]); // 9/12
    function authorizeOperatorByPartition(bytes32 partition, address operator) external; // 10/12
    function revokeOperatorByPartition(bytes32 partition, address operator) external; // 11/12
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool); // 12/12

    // Transfer Events
    event SentByPartition(
        bytes32 indexed fromPartition,
        address operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event ChangedPartition(
        bytes32 indexed fromPartition,
        bytes32 indexed toPartition,
        uint256 amount
    );

    // Operator Events
    event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

}
