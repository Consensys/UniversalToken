pragma solidity ^0.8.0;

import {IExtensionStorage} from "../../interface/IExtensionStorage.sol";
import {ExtensionLib} from "./ExtensionLib.sol";
import {IExtension, TransferData} from "../../interface/IExtension.sol";
import {ExtendableBase} from "./ExtendableBase.sol";

/**
* @dev ExtendableRouter provides internal functions to manage
* extensions, view extension data and invoke extension functions 
* (if the current call is an extension function)
*/
contract ExtendableRouter is ExtendableBase {

    /**
    * @dev Get the deployed extension proxy address that registered the provided
    * function selector. If no extension registered the given function selector,
    * then return address(0). If the extension that registered the function selector is disabled,
    * then the address(0) is returned
    * @param funcSig The function signature to lookup
    * @return address Returns the deployed enabled extension proxy address that registered the
    * provided function selector, otherwise address(0)
    */
    function _lookupExtension(bytes4 funcSig) internal view returns (address) {
        return ExtensionLib._functionToExtensionProxyAddress(funcSig);
    }

    /**
    * @dev Call a registered function selector. This will 
    * lookup the deployed extension proxy that registered the provided
    * function selector and call it. The current call data is forwarded.
    *
    * This call returns and exits the current call context.
    *
    * If the provided function selector is not registered by any enabled 
    * extensions, then the revert is thrown
    *
    * @param funcSig The registered function selector to call.
    */
    function _callFunction(bytes4 funcSig) private {
        // get extension proxy address from function selector
        address toCall = _lookupExtension(funcSig);
        require(toCall != address(0), "EXTROUTER: Function does not exist");

        if (_isExtensionProxyAddress(toCall)) {
            IExtensionStorage proxy = IExtensionStorage(payable(toCall));
            proxy.prepareCall(_msgSender());
        }

        uint256 value = msg.value;

        // Execute external function from facet using call and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := call(gas(), toCall, value, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    /**
    * @dev Register the extension at the given global extension address. This will deploy a new
    * ExtensionStorage contract to act as a proxy. The extension's proxy will
    * be initalized and all functions the extension has will be registered
    *
    * @param extension The deployed extension address to register
    */
    function _registerExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._registerExtension(extension, address(this), _msgSender());

        return true;
    }

    /**
    * @dev Remove the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Removing an extension deletes all data about the deployed extension proxy address
    * and makes the extension's storage inaccessable forever.
    *
    * @param extension Either the global extension address or the deployed extension proxy address to remove
    */
    function _removeExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._removeExtension(extension);

        return true;
    }

    /**
    * @dev Disable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Disabling the extension keeps the extension + storage live but simply disables
    * all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to disable
    */
    function _disableExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._disableExtension(extension);

        return true;
    }

    /**
    * @dev Enable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to enable
    */
    function _enableExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._enableExtension(extension);

        return true;
    }

    /**
    * @dev Get an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled
    */
    function _allExtension() internal view virtual returns (address[] memory) {
        return ExtensionLib._allExtensions();
    }

    /**
    * @dev Determine if a global extension address (or deployed extension proxy address)
    * is active. Active means the extension is registered and enabled
    *
    * @param extension Either the global extension address or the deployed extension proxy address to check if active
    */
    function _isActiveExtension(address extension) internal view virtual returns (bool) {
        return ExtensionLib._isActiveExtension(extension);
    }

    /**
    * @dev Check whether a given address is a deployed extension proxy address that
    * is registered.
    *
    * @param callsite The address to check
    */
    function _isExtensionProxyAddress(address callsite) internal view virtual returns (bool) {
        return ExtensionLib._isProxyAddress(callsite);
    }

    /**
    * @dev Determine if a given function selector is registered by an enabled
    * deployed extension proxy address. If no extension proxy exists or if the 
    * deployed extension proxy address is disabled, then false is returned
    *
    * @param funcSig The function selector to check
    * @return bool True if an enabled deployed extension proxy address has registered
    * the provided function selector, otherwise false.
    */
    function _isExtensionFunction(bytes4 funcSig) internal virtual view returns (bool) {
        address facet = _lookupExtension(funcSig);
        return _isExtensionProxyAddress(facet);
    }

    /**
    * @dev Forward the current call to the proper deployed extension proxy address. This
    * function assumes the current function selector is registered by an enabled deployed extension proxy address.
    *
    * This call returns and exits the current call context.
    */
    function _invokeExtensionFunction() internal virtual {
        require(_lookupExtension(msg.sig) != address(0), "No extension found with function signature");

        _callFunction(msg.sig);
    }
}