pragma solidity ^0.4.24;

import "../token/ERC777/IERC777TokensSender.sol";
import "./ERC820ImplementerMock.sol";


contract ERC777TokensSenderMock is IERC777TokensSender, ERC820ImplementerMock {

  constructor(string interfaceLabel)
    public
    ERC820ImplementerMock(interfaceLabel)
  {

  }

  function canTransfer(
    bytes32 /*partition*/,
    address from,
    address to,
    uint value,
    bytes data,
    bytes /*operatorData*/
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
    bytes data,
    bytes /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
  {
    require(_canTransfer(from, to, value, data), "A5:	Transfer Blocked - Sender not eligible");
  }

  function _canTransfer(
    address /*from*/,
    address /*to*/,
    uint /*value*/,
    bytes data
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
