pragma solidity ^0.8.0;

import {ERC20Core} from "../core/ERC20Core.sol";
import {ERC20DelegateCore} from "../core/ERC20DelegateCore.sol";
import {ERC20CoreExtendableBase} from "./ERC20CoreExtendableBase.sol";
import {ERC20ExtendableLib, TransferData} from "./ERC20ExtendableLib.sol";


contract ERC20DelegateCoreExtendable is ERC20CoreExtendableBase, ERC20DelegateCore {

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
    ) internal override(ERC20Core, ERC20CoreExtendableBase) {
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            from,
            to,
            amount,
            "",
            ""
        );

        require(ERC20ExtendableLib._delegatecallValidateTransfer(data), "Extension failed validation of transfer");
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
    ) internal override(ERC20Core, ERC20CoreExtendableBase) {
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            from,
            to,
            amount,
            "",
            ""
        );

        require(ERC20ExtendableLib._delegatecallAfterTransfer(data), "Extension failed execution of post-transfer");
    }

    function _getStorageLocation() internal override(ERC20DelegateCore, ERC20Core) pure returns (bytes32) {
        return ERC20DelegateCore._getStorageLocation();
    }

    function _confirmContext() internal override(ERC20DelegateCore, ERC20Core) view returns (bool) {
        return ERC20DelegateCore._confirmContext();
    }
}