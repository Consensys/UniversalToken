pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ExtensionContext} from "../../../extensions/ExtensionContext.sol";
import {ERC20ExtendableLib} from "./ERC20ExtendableLib.sol";
import {IERC20Extension, TransferData} from "../../../extensions/ERC20/IERC20Extension.sol";
import {Diamond} from "../../../tools/diamond/Diamond.sol";
import {ERC1820Client} from "../../../tools/ERC1820Client.sol";

abstract contract ERC20ExtendableBase is Diamond, Context, ERC1820Client {
    string constant internal ERC20_EXTENDABLE_INTERFACE_NAME = "ERC20Extendable";

    constructor() {
        ERC1820Client.setInterfaceImplementation(ERC20_EXTENDABLE_INTERFACE_NAME, address(this));
    }

    function _registerExtension(address extension) internal virtual returns (bool) {
        ERC20ExtendableLib._registerExtension(extension);

        return true;
    }

    function _removeExtension(address extension) internal virtual returns (bool) {
        ERC20ExtendableLib._removeExtension(extension);

        return true;
    }

    function _disableExtension(address extension) internal virtual returns (bool) {
        ERC20ExtendableLib._disableExtension(extension);

        return true;
    }

    function _enableExtension(address extension) internal virtual returns (bool) {
        ERC20ExtendableLib._enableExtension(extension);

        return true;
    }

    function _allExtension() internal view virtual returns (address[] memory) {
        return ERC20ExtendableLib._allExtensions();
    }

    function _isActiveExtension(address extension) internal view virtual returns (bool) {
        return ERC20ExtendableLib._isActiveExtension(extension);
    }

    function _isContextAddress(address callsite) internal view virtual returns (bool) {
        return ERC20ExtendableLib._isContextAddress(callsite);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _triggerBeforeTokenTransfer(TransferData memory data) internal virtual {
        require(ERC20ExtendableLib._validateTransfer(data), "Extension failed validation of transfer");
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _triggerAfterTokenTransfer(TransferData memory data) internal virtual {
        require(ERC20ExtendableLib._executeAfterTransfer(data), "Extension failed execution of post-transfer");
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external override payable {
        address facet = _lookupFacet(msg.sig);
        if (_isContextAddress(facet)) {
            ExtensionContext context = ExtensionContext(payable(facet));
            context.prepareCall(_msgSender(), msg.sig);
        }
        _callFunction(msg.sig);
    }
}