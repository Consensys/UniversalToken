pragma solidity ^0.8.0;

import {TokenEventManager} from "./TokenEventManager.sol";
import {TokenEventConstants} from "./TokenEventConstants.sol";
import {TransferData} from "../../interface/IExtension.sol";

/**
* @title Transfer Hooks for Extensions
* @notice This should be inherited by a token logic contract
* @dev ExtendableHooks provides the _triggerTokenTransferEvent and _triggerTokenApproveEvent internal
* function that can be used to notify extensions when a transfer/approval occurs.
*/
abstract contract ExtendableHooks is TokenEventManager, TokenEventConstants {

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
    function _triggerTokenTransferEvent(TransferData memory data) internal virtual {
        _trigger(TOKEN_TRANSFER_EVENT, data);
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
    function _triggerTokenApprovalEvent(TransferData memory data) internal virtual {
        _trigger(TOKEN_APPROVE_EVENT, data);
    }
}