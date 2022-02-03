pragma solidity ^0.8.0;

import {ExtensionLib} from "./ExtensionLib.sol";
import {IExtension, TransferData} from "../../extensions/IExtension.sol";
import {ExtendableBase} from "./ExtendableBase.sol";

abstract contract ExtendableHooks is ExtendableBase {

    function _validateTransferWithExtension(address extension, TransferData memory data) internal returns (bool) {
        IExtension ext = IExtension(extension);

        if (!ext.onTransferExecuted(data)) {
            return false;
        }
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
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
    function _triggerTokenTransfer(TransferData memory data) internal virtual {
        require(ExtensionLib._executeOnAllExtensions(_validateTransferWithExtension, data), "Extension failed validation of transfer");
    }
}