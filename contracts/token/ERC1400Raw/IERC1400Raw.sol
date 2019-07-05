/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

/**
 * @title IERC1400Raw token standard
 * @dev ERC1400Raw interface
 */
interface IERC1400Raw {

  function name() external view returns (string memory); // 1/13
  function symbol() external view returns (string memory); // 2/13
  function totalSupply() external view returns (uint256); // 3/13
  function balanceOf(address owner) external view returns (uint256); // 4/13
  function granularity() external view returns (uint256); // 5/13

  function controllers() external view returns (address[] memory); // 6/13
  function authorizeOperator(address operator) external; // 7/13
  function revokeOperator(address operator) external; // 8/13
  function isOperator(address operator, address tokenHolder) external view returns (bool); // 9/13

  function transferWithData(address to, uint256 value, bytes calldata data) external; // 10/13
  function transferFromWithData(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external; // 11/13

  function redeem(uint256 value, bytes calldata data) external; // 12/13
  function redeemFrom(address from, uint256 value, bytes calldata data, bytes calldata operatorData) external; // 13/13

  event TransferWithData(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256 value,
    bytes data,
    bytes operatorData
  );
  event Issued(address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);
  event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data, bytes operatorData);
  event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
  event RevokedOperator(address indexed operator, address indexed tokenHolder);

}
