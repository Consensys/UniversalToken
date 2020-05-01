pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Mintable.sol";

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract ERC721Token is ERC721Mintable, Ownable {

  constructor() public ERC721Mintable() {}

}