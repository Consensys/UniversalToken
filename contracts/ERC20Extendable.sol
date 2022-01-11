pragma solidity ^0.8.0;

import {UpgradableExtendableERC20Base} from "./tokens/ERC20/implementation/base/UpgradableExtendableERC20Base.sol";

contract ERC20Extendable is UpgradableExtendableERC20Base {
    constructor(
        string memory name_, string memory symbol_, bool allowMint, 
        bool allowBurn, address owner, uint256 initalSupply
    ) UpgradableExtendableERC20Base(name_, symbol_, allowMint, allowBurn, owner) {
        mint(msg.sender, initalSupply);
    }
}