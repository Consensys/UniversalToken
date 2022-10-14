// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../extensions/userExtensions/IERC1400TokensSender.sol";
import "../interface/ERC1820Implementer.sol";


contract ERC1400TokensSenderMock is IERC1400TokensSender, ERC1820Implementer {

  string constant internal ERC1400_TOKENS_SENDER = "ERC1400TokensSender";

  constructor() {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_SENDER);
  }

  function canTransfer(
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
    pure
    override
    returns(bool)
  {
    return(_canTransfer(from, to, value, data));
  }

  function tokensToTransfer(
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
    pure
    override
  {
    require(_canTransfer(from, to, value, data), "56"); // 0x56	invalid sender
  }

  function _canTransfer(
    address /*from*/,
    address /*to*/,
    uint /*value*/,
    bytes memory data
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    pure
    returns(bool)
  {
    bytes32 transferRevert = 0x1100000000000000000000000000000000000000000000000000000000000000; // Default sender hook failure data for the mock only
    bytes32 data32;
    assembly {
        data32 := mload(add(data, 32))
    }
    if (data32 == transferRevert) {
      return false;
    } else {
      return true;
    }
  }

}