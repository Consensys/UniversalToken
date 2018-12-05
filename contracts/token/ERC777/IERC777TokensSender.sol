/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;


interface IERC777TokensSender {
  function canSend(
    bytes32 tranche,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  ) external view returns(bool);

  function tokensToSend(
    address operator,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  ) external;
}
