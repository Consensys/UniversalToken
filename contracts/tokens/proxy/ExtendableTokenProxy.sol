pragma solidity ^0.8.0;

import {TokenProxy} from "./TokenProxy.sol";
import {IExtendableTokenProxy} from "../../interface/IExtendableTokenProxy.sol";
import {ExtendableRouter} from "../extension/ExtendableRouter.sol";
import {IExtendableTokenProxy} from "../../interface/IExtendableTokenProxy.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ExtensionLib} from "../extension/ExtensionLib.sol";
import {ExtensionStorage} from "../../extensions/ExtensionStorage.sol";
import {ITokenProxy} from "../../interface/ITokenProxy.sol";

abstract contract ExtendableTokenProxy is TokenProxy, ExtendableRouter, IExtendableTokenProxy {
    string constant internal EXTENDABLE_INTERFACE_NAME = "ExtendableToken";

    constructor(address logicAddress, address owner) TokenProxy(logicAddress, owner) {
        ERC1820Client.setInterfaceImplementation(EXTENDABLE_INTERFACE_NAME, address(this));
    }

    function allExtensions() external override view returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ExtensionLib library offers functions to do this
        return ExtensionLib._allExtensions();
    }

    // TODO storageAddressForExtension
    function proxyAddressForExtension(address extension) external override view returns (address) {
        return ExtensionLib._proxyAddressForExtension(extension);
    }

    
    function registerExtension(address extension) external override onlyManager returns (bool) {
        bool result = _registerExtension(extension);

        if (result) {
            address proxyAddress = ExtensionLib._proxyAddressForExtension(extension);
            ExtensionStorage proxy = ExtensionStorage(payable(proxyAddress));

            bytes32[] memory requiredRoles = proxy.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _addRole(proxyAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function removeExtension(address extension) external override onlyManager returns (bool) {
        bool result = _removeExtension(extension);

        if (result) {
            address proxyAddress = ExtensionLib._proxyAddressForExtension(extension);
            ExtensionStorage proxy = ExtensionStorage(payable(proxyAddress));

            bytes32[] memory requiredRoles = proxy.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _removeRole(proxyAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function disableExtension(address extension) external override onlyManager returns (bool) {
        return _disableExtension(extension);
    }

    function enableExtension(address extension) external override onlyManager returns (bool) {
        return _enableExtension(extension);
    }

    // Forward any function not found here to the logic
    // or to a registered extension
    function _fallback() internal override virtual {
        bool isExt = _isExtensionFunction(msg.sig);

        if (isExt) {
            _invokeExtensionFunction();
        } else {
            super._fallback();
        }
    }
}