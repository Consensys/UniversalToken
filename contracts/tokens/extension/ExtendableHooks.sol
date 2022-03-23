pragma solidity ^0.8.0;

import {IExtensionProxy} from "../../interface/IExtensionProxy.sol";
import {IExtension, TransferData} from "../../interface/IExtension.sol";
import {ExtendableBase} from "./ExtendableBase.sol";

/**
* @title Transfer Hooks for Extensions
* @notice This should be inherited by a token logic contract
* @dev ExtendableHooks provides the _triggerTokenTransfer internal
* function that can be used to notify extensions when a transfer occurs.
*/
abstract contract ExtendableHooks is ExtendableBase {

    /**
    * @dev Function that is invoked by ExtensionLib._executeOnAllExtensions for each
    * enabled extension that should receive a transfer event. It's not recommended to
    * invoke this manually.
    *
    * @param extension The deployed extension address to invoke the event on
    * @param data The transfer data to send along with the transfer event
    */
    function _validateTransferWithExtension(address extension, TransferData memory data) internal returns (bool) {
        IExtension ext = IExtension(extension);
        
        IExtensionProxy extProxy = IExtensionProxy(extension);
        extProxy.prepareCall(_msgSender());

        return ext.onTransferExecuted(data);
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
     * @param data The transfer data to that represents this transfer to send to extensions.
     */
    function _triggerTokenTransfer(TransferData memory data) internal virtual {
        require(_executeOnAllExtensions(_validateTransferWithExtension, data), "Extension failed validation of transfer");
    }
}