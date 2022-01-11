pragma solidity ^0.8.0;

import {ERC20Logic} from "../logic/ERC20Logic.sol";
import {ERC20Proxy} from "../../proxy/ERC20Proxy.sol";
import {ERC20Storage} from "../../storage/ERC20Storage.sol";
import {ERC20ExtendableLib} from "../../extensions/ERC20ExtendableLib.sol";
import {Diamond} from "../../../../tools/diamond/Diamond.sol";
import {ERC20ExtendableRouter} from "../../extensions/ERC20ExtendableRouter.sol";

contract UpgradableExtendableERC20Base is ERC20Proxy, ERC20ExtendableRouter {
    
    constructor(
        string memory name_, string memory symbol_, 
        bool allowMint, bool allowBurn, address owner
    ) ERC20Proxy(allowMint, allowBurn, owner) Diamond(_msgSender()) {
        ERC20Storage store = new ERC20Storage(address(this), name_, symbol_);
        ERC20Logic implementation = new ERC20Logic();

        _setImplementation(address(implementation));
        _setStorage(address(store));

        //Update the doamin seperator now that 
        //we've setup everything
        _updateDomainSeparator();
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);
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