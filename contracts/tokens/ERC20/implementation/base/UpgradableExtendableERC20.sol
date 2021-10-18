pragma solidity ^0.8.0;

import {ERC20CoreExtendable} from "../../extensions/ERC20CoreExtendable.sol";
import {ERC20Proxy} from "../../proxy/ERC20Proxy.sol";
import {BaseERC20Storage} from "../../storage/BaseERC20Storage.sol";

contract UpgradableERC20 is ERC20Proxy {
    
    constructor(string memory name_, string memory symbol_) ERC20Proxy() {
        BaseERC20Storage store = new BaseERC20Storage(name_, symbol_);
        ERC20CoreExtendable implementation = new ERC20CoreExtendable(address(this), address(store));

        _setImplementation(address(implementation));
        _setStore(address(store));

        store.changeCurrentWriter(address(implementation));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);

        _getStorageContract().changeCurrentWriter(implementation);
    }

    function registerExtension(address extension) external onlyManager returns (bool) {
        ERC20CoreExtendable extCore = ERC20CoreExtendable(address(_getImplementationContract()));

        return extCore.registerExtension(extension);
    }

    function removeExtension(address extension) external onlyManager returns (bool) {
        ERC20CoreExtendable extCore = ERC20CoreExtendable(address(_getImplementationContract()));

        return extCore.removeExtension(extension);
    }

    function disableExtension(address extension) external onlyManager returns (bool) {
        ERC20CoreExtendable extCore = ERC20CoreExtendable(address(_getImplementationContract()));

        return extCore.disableExtension(extension);
    }

    function enableExtension(address extension) external onlyManager returns (bool) {
        ERC20CoreExtendable extCore = ERC20CoreExtendable(address(_getImplementationContract()));

        return extCore.enableExtension(extension);
    }

    function allExtensions() external view returns (address[] memory) {
        ERC20CoreExtendable extCore = ERC20CoreExtendable(address(_getImplementationContract()));
        return extCore.allExtension();
    }
}