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
    if(tranche != hex"00" || from != address(0) || to != address(0) || amount != 0 || data.length != 0 || operatorData.length != 0){} // Line to avoid compilation warnings for unused variables.
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
    if(operator != address(0) || from != address(0) || to != address(0) || amount != 0 || data.length != 0 || operatorData.length != 0){} // Line to avoid compilation warnings for unused variables.
    require(_canReceive(from, to, amount, data), "A6: Transfer Blocked - Receiver not eligible");
  }

  function _canReceive(
    address from,
    address to,
    uint amount,
    bytes data
  ) internal pure returns(bool) {
    if(from != address(0) || to != address(0) || amount != 0){} // Line to avoid compilation warnings for unused variables.

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
