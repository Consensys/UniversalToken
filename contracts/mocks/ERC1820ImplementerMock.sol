pragma solidity ^0.5.0;

contract ERC1820ImplementerMock {
  bytes32 constant ERC1820_ACCEPT_MAGIC = keccak256(abi.encodePacked("ERC1820_ACCEPT_MAGIC"));

  bytes32 internal _interfaceHash;

  constructor(string memory interfaceLabel) public {
    _interfaceHash = keccak256(abi.encodePacked(interfaceLabel));
  }

  function canImplementInterfaceForAddress(bytes32 interfaceHash, address /*addr*/) // Comments to avoid compilation warnings for unused variables.
    external
    view
    returns(bytes32)
  {
    if(interfaceHash == _interfaceHash) {
      return ERC1820_ACCEPT_MAGIC;
    } else {
      return "";
    }
  }

}
