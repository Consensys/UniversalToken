pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../interface/ERC1820Implementer.sol";
import "../roles/MinterRole.sol";
import "../tools/DomainAware.sol";

contract ERC721Token is Ownable, ERC721, ERC721URIStorage, ERC721Enumerable, ERC721Burnable, ERC721Pausable,  MinterRole, ERC1820Implementer, AccessControlEnumerable, DomainAware {
  bytes32 constant internal VERSION = 0x0000000000000000000000000000000000000000000000000000000000000001;
  
  string constant internal ERC721_TOKEN = "ERC721Token";
  string internal _baseUri;

  constructor(string memory name, string memory symbol, string memory baseUri) ERC721(name, symbol) {
    ERC1820Implementer._setInterface(ERC721_TOKEN);
    _baseUri = baseUri;
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

  function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
      return ERC721URIStorage.tokenURI(tokenId);
  }

  function setTokenURI(uint256 tokenId, string memory uri) public virtual onlyMinter {
      _setTokenURI(tokenId, uri);
  }

  function _baseURI() internal view override virtual returns (string memory) {
      return _baseUri;
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

  function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
      ERC721URIStorage._burn(tokenId);
  }

  /************************************* Domain Aware ******************************************/
  function domainName() public override view returns (bytes memory) {
    return bytes(name());
  }

  function domainVersion() public override view returns (bytes32) {
    return VERSION;
  }
  /************************************************************************************************/
}