// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import "../interface/ERC1820Implementer.sol";
import "../roles/MinterRole.sol";

contract ERC20Token is Ownable, ERC20Burnable, ERC20Pausable, ERC1820Implementer, MinterRole {
  string constant internal ERC20_TOKEN = "ERC20Token";
  uint8 immutable internal _decimals;

  constructor(string memory name, string memory symbol, uint8 __decimals) ERC20(name, symbol) {
    ERC1820Implementer._setInterface(ERC20_TOKEN);
    _decimals = __decimals;
  }

  /**
    * @dev Returns the number of decimals used to get its user representation.
    * For example, if `decimals` equals `2`, a balance of `505` tokens should
    * be displayed to a user as `5,05` (`505 / 10 ** 2`).
    *
    * Tokens usually opt for a value of 18, imitating the relationship between
    * Ether and Wei. This is the value {ERC20} uses, unless this function is
    * overridden;
    *
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
  function decimals() public view virtual override returns (uint8) {
      return _decimals;
  }

    /**
    * @dev Function to mint tokens
    * @param to The address that will receive the minted tokens.
    * @param value The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
  function mint(address to, uint256 value) public onlyMinter returns (bool) {
      _mint(to, value);
      return true;
  }
  
  function _beforeTokenTransfer(
      address from,
      address to,
      uint256 amount
  ) internal override(ERC20Pausable, ERC20) {
    ERC20Pausable._beforeTokenTransfer(from, to, amount);
  }

  /************************************* Domain Aware ******************************************/
/*  function domainName() public override view returns (string memory) {
    return name();
  }

  function domainVersion() public override view returns (string memory) {
    return "1";
  }*/
  /************************************************************************************************/
}