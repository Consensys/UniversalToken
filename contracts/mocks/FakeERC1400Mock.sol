pragma solidity ^0.5.0;

import "../ERC1400.sol";


contract FakeERC1400Mock is ERC1400 {

  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    bytes32[] memory defaultPartitions
  )
    public
    ERC1400(name, symbol, granularity, controllers, defaultPartitions)
  {}

  /**
   * Override function to allow calling "tokensReceived" hook with wrong recipient ("to")
   */
  function _callPostTransferHooks(
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint256 value,
    bytes memory data,
    bytes memory operatorData
  )
    internal
  {
    address recipientImplementation;
    recipientImplementation = interfaceAddr(to, ERC1400_TOKENS_RECIPIENT);

    if (recipientImplementation != address(0)) {
      IERC1400TokensRecipient(recipientImplementation).tokensReceived(msg.data, partition, operator, from, from, value, data, operatorData);
    }
  }

  /**
   * Override function to allow redeeming tokens from address(0)
   */
  function transferFromWithData(address from, address to, uint256 value, bytes calldata /*data*/) external {
    _transferWithData(from, to, value);
  }

  /**
   * Override function to allow redeeming tokens from address(0)
   */
  function redeemFrom(address from, uint256 value, bytes calldata data)
    external
  {
    _redeem(msg.sender, from, value, data);
  }

}
