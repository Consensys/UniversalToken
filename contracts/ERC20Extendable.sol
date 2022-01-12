pragma solidity ^0.8.0;

import {ERC20Proxy} from "./tokens/ERC20/proxy/ERC20Proxy.sol";

contract ERC20Extendable is ERC20Proxy {
    constructor(
        string memory name_, string memory symbol_, bool allowMint, 
        bool allowBurn, address owner, uint256 initalSupply,
        address logicAddress
    ) ERC20Proxy(name_, symbol_, allowMint, allowBurn, owner, logicAddress) {
        mint(msg.sender, initalSupply);
    }
}