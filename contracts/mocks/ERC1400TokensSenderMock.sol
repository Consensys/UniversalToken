pragma solidity ^0.5.0;

import "../token/ERC1400Raw/IERC1400TokensSender.sol";
import "./ERC1820ImplementerMock.sol";


contract ERC1400TokensSenderMock is IERC1400TokensSender, ERC1820ImplementerMock {

  constructor(string memory interfaceLabel)
    public
    ERC1820ImplementerMock(interfaceLabel)
  {

  }

  function canTransfer(
    bytes32 /*partition*/,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
    view
    returns(bool)
  {
    return(_canTransfer(from, to, value, data));
  }

  function tokensToTransfer(
    bytes32 /*partition*/,
    address /*operator*/,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
  {
    require(_canTransfer(from, to, value, data), "A5"); // Transfer Blocked - Sender not eligible
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
