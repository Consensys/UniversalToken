pragma solidity ^0.4.24;

/// @title ERC-1410 Partially Fungible Token Standard
/// @dev See https://github.com/SecurityTokenStandard/EIP-Spec


//TODO: fix interface cannot inherit interface - interface IERC1410 is IERC777
interface IERC1410 {

    // Token Information
    function balanceOfByTranche(bytes32 tranche, address tokenHolder) external view returns (uint256); // 1/12
    function tranchesOf(address tokenHolder) external view returns (bytes32[]); // 2/12

    // Token Transfers
    function sendByTranche(bytes32 tranche, address to, uint256 amount, bytes data) external returns (bytes32); // 3/12
    function sendByTranches(bytes32[] tranches, address to, uint256[] amounts, bytes data) external returns (bytes32[]); // 4/12
    function operatorSendByTranche(bytes32 tranche, address from, address to, uint256 amount, bytes data, bytes operatorData) external returns (bytes32); // 5/12
    function operatorSendByTranches(bytes32[] tranches, address from, address to, uint256[] amounts, bytes data, bytes operatorData) external returns (bytes32[]); // 6/12

    // Default Tranche Management
    function getDefaultTranches(address tokenHolder) external view returns (bytes32[]); // 7/12 [OPTIONAL]
    function setDefaultTranches(bytes32[] tranches) external; // 8/12 [OPTIONAL]

    // Operators
    function defaultOperatorsByTranche(bytes32 tranche) external view returns (address[]); // 9/12
    function authorizeOperatorByTranche(bytes32 tranche, address operator) external; // 10/12
    function revokeOperatorByTranche(bytes32 tranche, address operator) external; // 11/12
    function isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) external view returns (bool); // 12/12

    // Transfer Events
    event SentByTranche(
        bytes32 indexed fromTranche,
        address operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    event ChangedTranche(
        bytes32 indexed fromTranche,
        bytes32 indexed toTranche,
        uint256 amount
    );

    // Operator Events
    /* event AuthorizedOperator(address indexed operator, address indexed tokenHolder); --> ERC777 */
    /* event RevokedOperator(address indexed operator, address indexed tokenHolder); --> ERC777 */

    event AuthorizedOperatorByTranche(bytes32 indexed tranche, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByTranche(bytes32 indexed tranche, address indexed operator, address indexed tokenHolder);

}
