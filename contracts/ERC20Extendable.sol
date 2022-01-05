pragma solidity ^0.8.0;

import {UpgradableExtendableERC20Base} from "./tokens/ERC20/implementation/base/UpgradableExtendableERC20Base.sol";

contract ERC20Extendable is UpgradableExtendableERC20Base {
    constructor(
        string memory name_, string memory symbol_, bool allowMint, 
        bool allowBurn, address owner, uint256 totalSupply
    ) UpgradableExtendableERC20Base(name_, symbol_, address(0), allowMint, allowBurn, owner) {
        _executeMint(msg.sender, msg.sender, totalSupply);
    }
}