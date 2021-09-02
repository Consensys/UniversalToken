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
  mapping(uint256 => string) _tokenUris;

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
  
  /**
  * @dev Function to set a URI for a given tokenId
  * @param tokenId The tokenId to assign the given URI
  * @param uri The URI to give the given tokenId
  */
  function setTokenUri(uint256 tokenId, string memory uri) external virtual onlyMinter returns (bool) {
      require(_exists(tokenId), "ERC721Metadata: Setting URI for nonexistent token");
      _tokenUris[tokenId] = uri;
      return true;
  }

  /**
    * @dev See {IERC721Metadata-tokenURI}.
    */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
      require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

      string memory uri = _tokenUris[tokenId];
      if (bytes(uri).length > 0) {
        return uri;
      } else {
        return super.tokenURI(tokenId);
      }
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