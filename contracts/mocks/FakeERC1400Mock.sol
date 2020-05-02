pragma solidity ^0.5.0;

import "../ERC1400.sol";


contract FakeERC1400Mock is ERC1400 {

  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    bytes32[] memory tokenDefaultPartitions
  )
    public
    ERC1400(name, symbol, granularity, controllers, tokenDefaultPartitions)
  {}

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
      IERC1400TokensRecipient(recipientImplementation).tokensReceived(msg.sig, partition, operator, from, from, value, data, operatorData);
    }
  }

}
