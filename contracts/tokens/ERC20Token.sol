pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract ERC20Token is ERC20Mintable, Ownable {

  constructor() public ERC20Mintable() {}

}