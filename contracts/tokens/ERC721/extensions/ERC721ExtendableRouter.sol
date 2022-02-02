pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ExtensionStorage} from "../../../extensions/ExtensionStorage.sol";
import {ExtensionLib} from "../../extension/ExtensionLib.sol";
import {ERC721ExtendableBase} from "./ERC721ExtendableBase.sol";

abstract contract ERC721ExtendableRouter is Context, ERC721ExtendableBase {

    function _lookupFacet(bytes4 funcSig) internal view returns (address) {
        return ExtensionLib._functionToExtensionContextAddress(funcSig);
    }

    function _callFunction(bytes4 funcSig) internal {
        // get facet from function selector
        address facet = _lookupFacet(funcSig);
        require(facet != address(0), "Diamond: Function does not exist");

        uint256 value = msg.value;

        // Execute external function from facet using call and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := call(gas(), facet, value, 0, calldatasize(), 0, 0)
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

    function _delegateCallFunction(bytes4 funcSig) internal {
        // get facet from function selector
        address facet = _lookupFacet(funcSig);
        require(facet != address(0), "Diamond: Function does not exist");

        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
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
        address facet = _lookupFacet(funcSig);
        return _isContextAddress(facet);
    }

    function _invokeExtensionFunction() internal virtual {
        address facet = _lookupFacet(msg.sig);
        if (_isContextAddress(facet)) {
            ExtensionStorage context = ExtensionStorage(payable(facet));
            context.prepareCall(_msgSender(), msg.sig);
        }
        _callFunction(msg.sig);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external virtual payable {
        _invokeExtensionFunction();
    }
    
    receive() external payable {}
}