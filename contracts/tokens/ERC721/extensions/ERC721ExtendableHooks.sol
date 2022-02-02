pragma solidity ^0.8.0;

import {ExtensionLib} from "../../extension/ExtensionLib.sol";
import {IERC20Extension, TransferData} from "../../../extensions/ERC20/IERC20Extension.sol";
import {ERC721ExtendableBase} from "./ERC721ExtendableBase.sol";

//TODO Add with ERC721 hooks
abstract contract ERC721ExtendableHooks is ERC721ExtendableBase {

    function _validateTransferWithExtension(address extension, TransferData memory data) internal view returns (bool) {
        IERC20Extension ext = IERC20Extension(extension);

        if (!ext.validateTransfer(data)) {
            return false;
        }
    }

    function _executeAfterTransferWithExtension(address extension, TransferData memory data) internal returns (bool) {
        IERC20Extension ext = IERC20Extension(extension);

        if (!ext.onTransferExecuted(data)) {
            return false;
        }
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
        require(ExtensionLib._erc20executeOnAllExtensions(_validateTransferWithExtension, data), "Extension failed validation of transfer");
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
        require(ExtensionLib._erc20executeOnAllExtensions(_executeAfterTransferWithExtension, data), "Extension failed execution of post-transfer");
    }
}