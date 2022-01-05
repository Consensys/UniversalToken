pragma solidity ^0.8.0;

import {ERC20LogicBase} from "./ERC20LogicBase.sol";
import {ERC20ExtendableLib} from "../../extensions/ERC20ExtendableLib.sol";
import {ERC20ExtendableBase} from "../../extensions/ERC20ExtendableBase.sol";
import {IERC20Extension, TransferData} from "../../../../extensions/ERC20/IERC20Extension.sol";


contract ERC20LogicExtendable is ERC20LogicBase, ERC20ExtendableBase {
    constructor(address proxy, address store) ERC20LogicBase(proxy, store) { }

    function registerExtension(address extension) public virtual confirmContext returns (bool) {
        return _registerExtension(extension);
    }

    function removeExtension(address extension) public virtual confirmContext returns (bool) {
        return _removeExtension(extension);
    }

    function disableExtension(address extension) external virtual confirmContext returns (bool) {
        return _disableExtension(extension);
    }

    function enableExtension(address extension) external virtual confirmContext returns (bool) {
        return _enableExtension(extension);
    }

    function allExtension() external view confirmContext returns (address[] memory) {
        return _allExtension();
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
    function _beforeTokenTransfer(TransferData memory data) internal override virtual {
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
    function _afterTokenTransfer(TransferData memory data) internal override virtual {
        require(ERC20ExtendableLib._executeAfterTransfer(data), "Extension failed execution of post-transfer");
    }
}