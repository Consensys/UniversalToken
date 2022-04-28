pragma solidity ^0.8.0;

import {ERC20Proxy} from "./tokens/proxy/ERC20/ERC20Proxy.sol";

contract ERC20Extendable is ERC20Proxy {
    uint256 public initalSupply;
    
    constructor(
        string memory name_, string memory symbol_, bool allowMint, 
        bool allowBurn, address owner, uint256 _initalSupply,
        uint256 maxSupply, address logicAddress
    ) ERC20Proxy(name_, symbol_, allowMint, allowBurn, owner, maxSupply, logicAddress) {
        initalSupply = _initalSupply;

        bool isNotOwner = owner != _msgSender();

        if (isNotOwner) {
            //Temporaroly add minter role to msg.sender
            //If the sender is not the final owner
            _addRole(_msgSender(), TOKEN_MINTER_ROLE); 
        }

        _mint(owner, initalSupply);

        if (isNotOwner) {
            //Remove after mint is complete
            //If the sender is not the final owner
            _removeRole(_msgSender(), TOKEN_MINTER_ROLE);
        }
    }
}