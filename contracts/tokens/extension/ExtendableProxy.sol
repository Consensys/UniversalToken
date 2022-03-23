pragma solidity ^0.8.0;

import {IExtensionProxy} from "../../interface/IExtensionProxy.sol";
import {IExtension, TransferData} from "../../interface/IExtension.sol";
import {ExtendableBase} from "./ExtendableBase.sol";

/**
* @title Router contract for Extensions
* @notice This should be inherited by token proxy contracts
* @dev ExtendableProxy provides internal functions to manage
* extensions, view extension data and invoke extension functions 
* (if the current call is an extension function)
*/
contract ExtendableProxy is ExtendableBase {

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
        address toCall = _functionToExtensionProxyAddress(funcSig);
        require(toCall != address(0), "EXTROUTER: Function does not exist");

        if (_isExtensionProxyAddress(toCall)) {
            IExtensionProxy proxy = IExtensionProxy(payable(toCall));
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
    * @dev Determine if a given function selector is registered by an enabled
    * deployed extension proxy address. If no extension proxy exists or if the 
    * deployed extension proxy address is disabled, then false is returned
    *
    * @param funcSig The function selector to check
    * @return bool True if an enabled deployed extension proxy address has registered
    * the provided function selector, otherwise false.
    */
    function _isExtensionFunction(bytes4 funcSig) internal virtual view returns (bool) {
        return _functionToExtensionProxyAddress(funcSig) != address(0);
    }

    /**
    * @dev Forward the current call to the proper deployed extension proxy address. This
    * function assumes the current function selector is registered by an enabled deployed extension proxy address.
    *
    * This call returns and exits the current call context.
    */
    function _invokeExtensionFunction() internal virtual {
        require(_isExtensionFunction(msg.sig), "No extension found with function signature");

        _callFunction(msg.sig);
    }
}