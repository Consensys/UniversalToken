pragma solidity ^0.8.0;

import {ERC20LogicExtendable} from "../logic/ERC20LogicExtendable.sol";
import {ERC20Logic} from "../logic/ERC20Logic.sol";
import {ERC20Proxy} from "../../proxy/ERC20Proxy.sol";
import {ERC20Storage} from "../../storage/ERC20Storage.sol";
import {ERC20ExtendableLib} from "../../extensions/ERC20ExtendableLib.sol";
import {Diamond} from "../../../../tools/diamond/Diamond.sol";

contract UpgradableExtendableERC20Base is ERC20Proxy, Diamond {
    
    constructor(
        string memory name_, string memory symbol_, 
        address core_implementation_, bool allowMint, 
        bool allowBurn, address owner
    ) ERC20Proxy(allowMint, allowBurn, owner) Diamond(_msgSender()) {
        ERC20Storage store = new ERC20Storage(name_, symbol_);
        ERC20Logic implementation;
        if (core_implementation_ != address(0)) {
            implementation = ERC20Logic(core_implementation_);
        } else {
            implementation = new ERC20Logic();
        }

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
        return _invokeCore(abi.encodeWithSelector(ERC20LogicExtendable.registerExtension.selector, extension))[0] == 0x01;
    }

    function removeExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20LogicExtendable.removeExtension.selector, extension))[0] == 0x01;
    }

    function disableExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20LogicExtendable.disableExtension.selector, extension))[0] == 0x01;
    }

    function enableExtension(address extension) external onlyManager returns (bool) {
        return _invokeCore(abi.encodeWithSelector(ERC20LogicExtendable.enableExtension.selector, extension))[0] == 0x01;
    }

    function allExtensions() external view returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ERC20ExtendableLib library offers functions to do this
        return ERC20ExtendableLib._allExtensions();
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external override payable {
        _callFunction(msg.sig);
    }
}