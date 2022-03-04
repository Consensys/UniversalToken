pragma solidity ^0.8.0;

import {ERC20Proxy} from "./tokens/ERC20/proxy/ERC20Proxy.sol";

contract ERC20Extendable is ERC20Proxy {
    uint256 public initalSupply;
    
    constructor(
        string memory name_, string memory symbol_, bool allowMint, 
        bool allowBurn, address owner, uint256 _initalSupply,
        uint256 maxSupply, address logicAddress
    ) ERC20Proxy(name_, symbol_, allowMint, allowBurn, owner, maxSupply, logicAddress) {
        initalSupply = _initalSupply;
        _mint(owner, initalSupply);
    }
}