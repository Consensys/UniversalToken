pragma solidity ^0.8.0;

import {ERC20Core} from "../implementation/core/ERC20Core.sol";
import {ERC20DelegateCore} from "../implementation/core/ERC20DelegateCore.sol";
import {ERC20CoreExtendableBase} from "./ERC20CoreExtendableBase.sol";
import {ERC20ExtendableLib} from "./ERC20ExtendableLib.sol";
import {IERC20Extension, TransferData} from "../../../extensions/IERC20Extension.sol";
import {LibDiamond} from "./diamond/LibDiamond.sol";


contract ERC20DelegateCoreExtendable is ERC20CoreExtendableBase, ERC20DelegateCore {

    function registerExtension(address extension) public override confirmContext returns (bool) {
        bool result = super.registerExtension(extension);

        if (result) {
            _registerExtensionFunctions(extension);
        }

        return result;
    }

    function removeExtension(address extension) public override(ERC20CoreExtendableBase) confirmContext returns (bool) {
        bool result = super.removeExtension(extension);

        if (result) {
            _removeExtensionFunctions(extension);
        }

        return true;
    }
    
    function _registerExtensionFunctions(address extensionAddress) internal {
        IERC20Extension extension = IERC20Extension(extensionAddress);

        //First register the function selectors with the diamond
        bytes4[] memory externalFunctions = extension.externalFunctions();

        if (externalFunctions.length > 0) {
            LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
            cut[0] = LibDiamond.FacetCut({
                facetAddress: extensionAddress, 
                action: LibDiamond.FacetCutAction.Add, 
                functionSelectors: externalFunctions
            });
            LibDiamond.diamondCut(cut, extensionAddress, abi.encodeWithSelector(IERC20Extension.initalize.selector));
        }
    }

    function _removeExtensionFunctions(address extensionAddress) internal {
        IERC20Extension extension = IERC20Extension(extensionAddress);

        //First register the function selectors with the diamond
        bytes4[] memory externalFunctions = extension.externalFunctions();

        if (externalFunctions.length > 0) {
            LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
            cut[0] = LibDiamond.FacetCut({
                facetAddress: extensionAddress, 
                action: LibDiamond.FacetCutAction.Remove, 
                functionSelectors: externalFunctions
            });

            //Dont call initalize when removing functions
            LibDiamond.diamondCut(cut, address(0), "");
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
    function _beforeTokenTransfer(TransferData memory data) internal override(ERC20Core, ERC20CoreExtendableBase) {
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
    function _afterTokenTransfer(TransferData memory data) internal override(ERC20Core, ERC20CoreExtendableBase) {
        require(ERC20ExtendableLib._delegatecallAfterTransfer(data), "Extension failed execution of post-transfer");
    }

    function _getStorageLocation() internal override(ERC20DelegateCore, ERC20Core) pure returns (bytes32) {
        return ERC20DelegateCore._getStorageLocation();
    }

    function _confirmContext() internal override(ERC20DelegateCore, ERC20Core) view returns (bool) {
        return ERC20DelegateCore._confirmContext();
    }

    function _getProxyAddress() internal override(ERC20Core, ERC20DelegateCore) virtual view returns (address) {
        return ERC20DelegateCore._getProxyAddress();
    }
}