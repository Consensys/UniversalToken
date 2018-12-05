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
    bytes32 tranche,
    address from,
    address to,
    uint amount,
    bytes data,
    bytes operatorData
  )
    external
    view
    returns(bool)
  {
    require(tranche != hex"00" || from != address(0) || to != address(0) || amount != 0 || data.length != 0 || operatorData.length != 0);
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
    require(operator != address(0) || from != address(0) || to != address(0) || amount != 0 || data.length != 0 || operatorData.length != 0);
    require(_canReceive(from, to, amount, data));
  }

  function _canReceive(
    address from,
    address to,
    uint amount,
    bytes data
  ) internal pure returns(bool) {
    require(from != address(0) || to != address(0) || amount != 0);

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
