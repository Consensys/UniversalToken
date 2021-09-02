pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../interface/ERC1820Implementer.sol";
import "../roles/MinterRole.sol";

contract ERC721Token is Ownable, ERC721, ERC721Enumerable, ERC721Burnable, ERC721Pausable,  MinterRole, ERC1820Implementer, AccessControlEnumerable {
  string constant internal ERC721_TOKEN = "ERC721Token";

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    ERC1820Implementer._setInterface(ERC721_TOKEN);
  }

  /**
  * @dev Function to mint tokens
  * @param to The address that will receive the minted tokens.
  * @param tokenId The token id to mint.
  * @return A boolean that indicates if the operation was successful.
  */
  function mint(address to, uint256 tokenId) public onlyMinter returns (bool) {
      _mint(to, tokenId);
      return true;
  }

  function _beforeTokenTransfer(
      address from,
      address to,
      uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
      super._beforeTokenTransfer(from, to, tokenId);
  }

  /**
    * @dev See {IERC165-supportsInterface}.
    */
  function supportsInterface(bytes4 interfaceId)
      public
      view
      virtual
      override(AccessControlEnumerable, ERC721, ERC721Enumerable)
      returns (bool)
  {
      return super.supportsInterface(interfaceId);
  }
}