pragma solidity ^0.8.0;

import {ERC20Core} from "../implementation/core/ERC20Core.sol";
import {ERC20ExtendableLib} from "./ERC20ExtendableLib.sol";
import {IERC20Extension, TransferData} from "../../../extensions/IERC20Extension.sol";


abstract contract ERC20CoreExtendableBase is ERC20Core {

    function registerExtension(address extension) public virtual confirmContext returns (bool) {
        ERC20ExtendableLib._registerExtension(extension);

        return true;
    }

    function removeExtension(address extension) public virtual confirmContext returns (bool) {
        ERC20ExtendableLib._removeExtension(extension);

        return true;
    }

    function disableExtension(address extension) external virtual confirmContext returns (bool) {
        ERC20ExtendableLib._disableExtension(extension);

        return true;
    }

    function enableExtension(address extension) external virtual confirmContext returns (bool) {
        ERC20ExtendableLib._enableExtension(extension);

        return true;
    }

    function allExtension() external view confirmContext returns (address[] memory) {
        return ERC20ExtendableLib._allExtensions();
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
    function _beforeTokenTransfer(
        address caller,
        address from,
        address to,
        uint256 amount
    ) internal override virtual {
        TransferData memory data = TransferData(
            _getProxyAddress(),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            from,
            to,
            amount,
            "",
            ""
        );

        require(ERC20ExtendableLib._callValidateTransfer(data), "Extension failed validation of transfer");
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
    function _afterTokenTransfer(
        address caller,
        address from,
        address to,
        uint256 amount
    ) internal override virtual {
        TransferData memory data = TransferData(
            _getProxyAddress(),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            from,
            to,
            amount,
            "",
            ""
        );

        require(ERC20ExtendableLib._callAfterTransfer(data), "Extension failed execution of post-transfer");
    }
}