// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../extensions/userExtensions/IERC1400TokensRecipient.sol";
import "../interface/ERC1820Implementer.sol";


contract ERC1400TokensRecipientMock is IERC1400TokensRecipient, ERC1820Implementer {

  string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

  constructor() {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_RECIPIENT);
  }

  function canReceive(
    bytes calldata /*payload*/,
    bytes32 /*partition*/,
    address /*operator*/,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
    override
    pure
    returns(bool)
  {
    return(_canReceive(from, to, value, data));
  }

  function tokensReceived(
    bytes calldata /*payload*/,
    bytes32 /*partition*/,
    address /*operator*/,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
    override
    pure
  {
    require(_canReceive(from, to, value, data), "57"); // 0x57	invalid receiver
  }

  function _canReceive(
    address /*from*/,
    address /*to*/,
    uint /*value*/,
    bytes memory data
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    pure
    returns(bool)
  {
    bytes32 receiveRevert = 0x2200000000000000000000000000000000000000000000000000000000000000; // Default recipient hook failure data for the mock only
    bytes32 data32;
    assembly {
        data32 := mload(add(data, 32))
    }
    if (data32 == receiveRevert) {
      return false;
    } else {
      return true;
    }
  }

}
