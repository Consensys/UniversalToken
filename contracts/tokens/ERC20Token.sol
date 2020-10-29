pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

import "../interface/ERC1820Implementer.sol";

contract ERC20Token is Ownable, ERC20Mintable, ERC20Burnable, ERC20Pausable, ERC20Detailed, ERC1820Implementer {
  string constant internal ERC20_TOKEN = "ERC20Token";

  constructor(string memory name, string memory symbol, uint8 decimals) public ERC20Detailed(name, symbol, decimals) {
    ERC1820Implementer._setInterface(ERC20_TOKEN);
  }

}