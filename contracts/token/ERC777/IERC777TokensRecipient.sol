/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

/**
 * @title IERC777TokensRecipient
 * @dev ERC777TokensRecipient interface
 */
interface IERC777TokensRecipient {

  function canReceive(
    bytes32 partition,
    address from,
    address to,
    uint value,
    bytes data,
    bytes operatorData
  ) external view returns(bool);

  function tokensReceived(
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint value,
    bytes data,
    bytes operatorData
  ) external;

}
