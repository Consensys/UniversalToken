/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import {IERC1820Implementer} from "../interface/IERC1820Implementer.sol";


contract ERC1820Implementer is IERC1820Implementer {
  bytes32 constant ERC1820_ACCEPT_MAGIC = keccak256(abi.encodePacked("ERC1820_ACCEPT_MAGIC"));

  mapping(address => mapping(bytes32 => bool)) internal _interfaceHashes;

  function canImplementInterfaceForAddress(bytes32 interfaceHash, address addr)
    external
    override
    view
    returns(bytes32)
  {
    //If we implement the interface for this address
    //or if we implement the interface for every address
    if(_interfaceHashes[addr][interfaceHash] || _interfaceHashes[address(0)][interfaceHash]) {
      return ERC1820_ACCEPT_MAGIC;
    } else {
      return "";
    }
  }

  //TODO Rename to _setInterfaceForAll
  function _setInterface(string memory interfaceLabel) internal {
    _setInterface(interfaceLabel, true, true);
  }

  function _setInterface(string memory interfaceLabel, bool forSelf, bool forAll) internal {
    //Implement the interface for myself
    if (forSelf)
      _interfaceHashes[address(this)][keccak256(abi.encodePacked(interfaceLabel))] = true;

    //Implement the interface for everyone
    if (forAll)
      _interfaceHashes[address(0)][keccak256(abi.encodePacked(interfaceLabel))] = true;
  }

  function _setInterfaceForAddress(string memory interfaceLabel, address addr) internal {
    //Implement the interface for addr
    _interfaceHashes[addr][keccak256(abi.encodePacked(interfaceLabel))] = true;
  }

}
