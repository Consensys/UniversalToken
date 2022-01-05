pragma solidity ^0.8.0;

import {ERC20LogicExtendable} from "../logic/ERC20LogicExtendable.sol";
import {ERC20Logic} from "../logic/ERC20Logic.sol";
import {ERC20Proxy} from "../../proxy/ERC20Proxy.sol";
import {ERC20Storage} from "../../storage/ERC20Storage.sol";
import {ERC20ExtendableLib} from "../../extensions/ERC20ExtendableLib.sol";
import {Diamond} from "../../../../tools/diamond/Diamond.sol";
import {ERC20ExtendableBase} from "../../extensions/ERC20ExtendableBase.sol";

contract UpgradableExtendableERC20Base is ERC20Proxy, ERC20ExtendableBase {
    
    constructor(
        string memory name_, string memory symbol_, 
        bool allowMint, bool allowBurn, address owner
    ) ERC20Proxy(allowMint, allowBurn, owner) Diamond(_msgSender()) {
        ERC20Storage store = new ERC20Storage(name_, symbol_);
        ERC20LogicExtendable implementation = new ERC20LogicExtendable(address(store));

        //TODO Check interface exported by core_implementation_

        _setImplementation(address(implementation));
        _setStore(address(store));

        //Only we can modify the storage contract
        //(and the ERC20DelegateCore contract given when we run delegatecall)
        store.changeCurrentWriter(address(this));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);

        _getStorageContract().changeCurrentWriter(implementation);
    }

    function registerExtension(address extension) external onlyManager returns (bool) {
        return _registerExtension(extension);
    }

    function removeExtension(address extension) external onlyManager returns (bool) {
        return _removeExtension(extension);
    }

    function disableExtension(address extension) external onlyManager returns (bool) {
        return _disableExtension(extension);
    }

    function enableExtension(address extension) external onlyManager returns (bool) {
        return _enableExtension(extension);
    }

    function allExtensions() external view returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ERC20ExtendableLib library offers functions to do this
        return ERC20ExtendableLib._allExtensions();
    }
}