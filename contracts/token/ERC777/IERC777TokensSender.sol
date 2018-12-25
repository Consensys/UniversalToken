/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

/**
 * @title IERC777TokensSender
 * @dev ERC777TokensSender interface
 */
interface IERC777TokensSender {

  function canTransfer(
    bytes32 partition,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  ) external view returns(bool);

  function tokensToTransfer(
    address operator,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  ) external;

}
