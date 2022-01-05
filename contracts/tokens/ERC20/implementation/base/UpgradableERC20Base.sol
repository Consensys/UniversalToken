pragma solidity ^0.8.0;

import {ERC20Logic} from "../../implementation/logic/ERC20Logic.sol";
import {ERC20Proxy} from "../../proxy/ERC20Proxy.sol";
import {ERC20Storage} from "../../storage/ERC20Storage.sol";

contract UpgradableERC20Base is ERC20Proxy {
    
    constructor(
        string memory name_, string memory symbol_,
        bool allowMint, bool allowBurn, address owner
    ) ERC20Proxy(allowMint, allowBurn, owner) {
        ERC20Storage store = new ERC20Storage(name_, symbol_);
        ERC20Logic implementation = new ERC20Logic();

        _setImplementation(address(implementation));
        _setStore(address(store));

        store.changeCurrentWriter(address(implementation));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);

        _getStorageContract().changeCurrentWriter(implementation);
    }
}