/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 *
 * Potential issues:
 * - Presence of 'data' field in burn and operatorBurn
 */
pragma solidity ^0.4.24;


interface IERC777 {
    function name() external view returns (string);
    function symbol() external view returns (string);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function granularity() external view returns (uint256);

    function defaultOperators() external view returns (address[]);
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;
    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);

    function send(address to, uint256 amount, bytes data) external;
    function operatorSend(address from, address to, uint256 amount, bytes data, bytes operatorData) external;

    function burn(uint256 amount) external;
    function operatorBurn(address from, uint256 amount, bytes operatorData) public;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes operatorData);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
}
