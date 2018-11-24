pragma solidity ^0.4.24;

import "../token/ERC777/IERC777TokensSender.sol";
import "./ERC820ImplementerMock.sol";


contract ERC777TokensSenderMock is IERC777TokensSender, ERC820ImplementerMock {

  event Test1(bytes32 b1, bytes32 b2);

  constructor(string interfaceLabel)
    public
    ERC820ImplementerMock(interfaceLabel)
  {

  }

  function canSend(
    address from,
    address to,
    bytes32 tranche,
    uint amount,
    bytes data
  )
    external
    view
    returns(bool)
  {
    return true;
  }

  function tokensToSend(
    address operator,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  ) external {
    require(_canSend(from, to, amount, data));
  }

  function _canSend(
    address from,
    address to,
    uint amount,
    bytes data
  ) internal returns(bool) {
    bytes32 sendRevert = 0x1111000000000000000000000000000000000000000000000000000000000000; // Default sender hook failure data for the mock only
    bytes32 data32;
    assembly {
        data32 := mload(add(data, 32))
    }
    emit Test1(data32, sendRevert);
    if (data32 == sendRevert) {
      return false;
    } else {
      return true;
    }
  }

}
