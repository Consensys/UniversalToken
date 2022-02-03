pragma solidity ^0.8.0;

import {ProxyContext} from "../../proxy/context/ProxyContext.sol";
import {ExtensionStorage} from "../../extensions/ExtensionStorage.sol";
import {ExtensionLib} from "./ExtensionLib.sol";
import {IExtension, TransferData} from "../../extensions/IExtension.sol";
import {ExtendableBase} from "./ExtendableBase.sol";

contract ExtendableRouter is ProxyContext, ExtendableBase {

    function _lookupExtension(bytes4 funcSig) internal view returns (address) {
        return ExtensionLib._functionToExtensionContextAddress(funcSig);
    }

    function _callFunction(bytes4 funcSig) private {
        // get extension context address from function selector
        address toCall = _lookupExtension(funcSig);
        require(toCall != address(0), "EXTROUTER: Function does not exist");

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

    function _registerExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._registerExtension(extension);

        return true;
    }

    function _removeExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._removeExtension(extension);

        return true;
    }

    function _disableExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._disableExtension(extension);

        return true;
    }

    function _enableExtension(address extension) internal virtual returns (bool) {
        ExtensionLib._enableExtension(extension);

        return true;
    }

    function _allExtension() internal view virtual returns (address[] memory) {
        return ExtensionLib._allExtensions();
    }

    function _isActiveExtension(address extension) internal view virtual returns (bool) {
        return ExtensionLib._isActiveExtension(extension);
    }

    function _isContextAddress(address callsite) internal view virtual returns (bool) {
        return ExtensionLib._isContextAddress(callsite);
    }

    function _isExtensionFunction(bytes4 funcSig) internal virtual view returns (bool) {
        address facet = _lookupExtension(funcSig);
        return _isContextAddress(facet);
    }

    function _invokeExtensionFunction() internal virtual {
        address facet = _lookupExtension(msg.sig);
        if (_isContextAddress(facet)) {
            ExtensionStorage context = ExtensionStorage(payable(facet));
            context.prepareCall(_msgSender(), msg.sig);
        }
        _callFunction(msg.sig);
    }
}