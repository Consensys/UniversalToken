pragma solidity ^0.8.0;

import {ERC721Proxy} from "./tokens/ERC721/proxy/ERC721Proxy.sol";

contract ERC721Extendable is ERC721Proxy {
    
    constructor(
        string memory name_, string memory symbol_, bool allowMint, 
        bool allowBurn, address owner, uint256 _initalSupply,
        uint256 maxSupply, address logicAddress
    ) ERC721Proxy(name_, symbol_, allowMint, allowBurn, owner, maxSupply, logicAddress) { }
}