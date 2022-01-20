pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ExtensionStorage} from "../../../extensions/ExtensionStorage.sol";
import {ExtensionLib} from "../../extension/ExtensionLib.sol";
import {IERC20Extension, TransferData} from "../../../extensions/ERC20/IERC20Extension.sol";
import {Diamond} from "../../../proxy/diamond/Diamond.sol";
import {ERC20ExtendableBase} from "./ERC20ExtendableBase.sol";

abstract contract ERC20ExtendableRouter is Diamond, Context, ERC20ExtendableBase {


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

    function _invokeExtensionFunction() internal {
        address facet = _lookupFacet(msg.sig);
        if (_isContextAddress(facet)) {
            ExtensionStorage context = ExtensionStorage(payable(facet));
            context.prepareCall(_msgSender(), msg.sig);
        }
        _callFunction(msg.sig);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external virtual override payable {
        _invokeExtensionFunction();
    }
}