pragma solidity ^0.8.0;

import {ERC20Core} from "../../implementation/core/ERC20Core.sol";
import {ERC20Proxy} from "../../proxy/ERC20Proxy.sol";
import {BaseERC20Storage} from "../../storage/BaseERC20Storage.sol";

contract UpgradableERC20 is ERC20Proxy {
    
    constructor(
        string memory name_, string memory symbol_,
        bool allowMint, bool allowBurn, address owner
    ) ERC20Proxy(allowMint, allowBurn, owner) {
        BaseERC20Storage store = new BaseERC20Storage(name_, symbol_);
        ERC20Core implementation = new ERC20Core(address(this), address(store));

        _setImplementation(address(implementation));
        _setStore(address(store));

        store.changeCurrentWriter(address(implementation));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);

        _getStorageContract().changeCurrentWriter(implementation);
    }
}