/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 *
 * Potential issues:
 * - Presence of 'data' field in burn and operatorBurn
 */
pragma solidity ^0.4.24;


interface IERC777 {
  function name() external view returns (string); // 1/13
  function symbol() external view returns (string); // 2/13
  function totalSupply() external view returns (uint256); // 3/13
  function balanceOf(address owner) external view returns (uint256); // 4/13
  function granularity() external view returns (uint256); // 5/13

  function defaultOperators() external view returns (address[]); // 6/13
  function authorizeOperator(address operator) external; // 7/13
  function revokeOperator(address operator) external; // 8/13
  function isOperatorFor(address operator, address tokenHolder) external view returns (bool); // 9/13

  function sendTo(address to, uint256 amount, bytes data) external; // 10/13
  function operatorSendTo(address from, address to, uint256 amount, bytes data, bytes operatorData) external; // 11/13

  function burn(uint256 amount, bytes data) external; // 12/13
  function operatorBurn(address from, uint256 amount, bytes operatorData) external; // 13/13

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
