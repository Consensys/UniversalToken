pragma solidity ^0.8.0;

import {TokenProxy} from "./TokenProxy.sol";
import {ExtendableRouter} from "../tokens/extension/ExtendableRouter.sol";
import {IExtendable} from "../tokens/extension/IExtendable.sol";

abstract contract ExtendableTokenProxy is TokenProxy, ExtendableRouter, IExtendable {
    function allExtensions() external override view returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ExtensionLib library offers functions to do this
        return ExtensionLib._allExtensions();
    }

    // TODO storageAddressForExtension
    function contextAddressForExtension(address extension) external override view returns (address) {
        return ExtensionLib._contextAddressForExtension(extension);
    }

    
    function registerExtension(address extension) external override onlyManager returns (bool) {
        bool result = _registerExtension(extension, _callsiteAddress());

        if (result) {
            address contextAddress = ExtensionLib._contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _addRole(ctxAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function removeExtension(address extension) external override onlyManager returns (bool) {
        bool result = _removeExtension(extension);

        if (result) {
            address contextAddress = ExtensionLib._contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _removeRole(ctxAddress, requiredRoles[i]);
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
    fallback() external override payable {
        bool isExt = _isExtensionFunction(msg.sig);

        if (isExt) {
            _invokeExtensionFunction();
        } else {
            _delegateCurrentCall();
        }
    }
}