pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "../interface/ERC1820Implementer.sol";

contract ERC721Token is Ownable, ERC721PresetMinterPauserAutoId, ERC1820Implementer {
  string constant internal ERC721_TOKEN = "ERC721Token";

  constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721PresetMinterPauserAutoId(name, symbol, baseTokenURI) {
    ERC1820Implementer._setInterface(ERC721_TOKEN);
  }
}