pragma solidity ^0.5.0;

import "../token/ERC1400Raw/IERC1400TokensValidator.sol";
import "./ERC1820ImplementerMock.sol";


contract ERC1400TokensValidatorMock is IERC1400TokensValidator, ERC1820ImplementerMock {

  constructor(string memory interfaceLabel)
    public
    ERC1820ImplementerMock(interfaceLabel)
  {}

  function canValidate(
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
    return(_canValidate(from, to, value, data));
  }

  function tokensToValidate(
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
    require(_canValidate(from, to, value, data), "A7"); // Transfer Blocked - Identity restriction
  }

  function _canValidate(
    address /*from*/,
    address /*to*/,
    uint /*value*/,
    bytes memory data
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    pure
    returns(bool)
  {
    bytes32 transferRevert = 0x3300000000000000000000000000000000000000000000000000000000000000; // Default sender hook failure data for the mock only
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