pragma solidity ^0.4.24;

import "../token/ERC777/IERC777TokensRecipient.sol";
import "./ERC820ImplementerMock.sol";


contract ERC777TokensRecipientMock is IERC777TokensRecipient, ERC820ImplementerMock {

  constructor(string interfaceLabel)
    public
    ERC820ImplementerMock(interfaceLabel)
  {

  }

  function canReceive(
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

  function tokensReceived(
    address operator,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  ) external {
    require(_canReceive(from, to, amount, data));
  }

  function _canReceive(
    address from,
    address to,
    uint amount,
    bytes data
  ) internal returns(bool) {
    bytes32 receiveRevert = 0x2222000000000000000000000000000000000000000000000000000000000000; // Default recipient hook failure data for the mock only
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
