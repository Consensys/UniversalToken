// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20CoreFaucet } from "./ERC20Core.sol";
import { IERC20Extension } from "../interfaces/IERC20Extension.sol";
import { ITokenExtensionFacet } from "../interfaces/ITokenExtensionFacet.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { LibTokenExtensionFacet, TokenExtensionFacetData, TokenExtensionData } from "../libraries/LibTokenExtensionFacet.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract TokenExtensionFacet is IERC20, ITokenExtensionFacet {

    function _initalize(string memory name, string memory symbol, uint8 decimals, address contractOwner) external override {
        TokenExtensionFacetData storage s = LibTokenExtensionFacet.tokenExtensionFacetStorage();
        require(s.erc20Core == address(0), "ERC20Core already setup");

        ERC20CoreFaucet core = new ERC20CoreFaucet(name, symbol, decimals);

        //Since we just deployed 
        core.transferOwnership(contractOwner);

        s.erc20Core = address(core);

        _registerExtensionFunctions(s.erc20Core);
    }

    function registerExtension(address extensionAddress) external override {
        LibDiamond.enforceIsContractOwner();

        TokenExtensionFacetData storage s = LibTokenExtensionFacet.tokenExtensionFacetStorage();

        _registerExtensionFunctions(extensionAddress);
    }

    function removeExtension(address extension) external override {
        LibDiamond.enforceIsContractOwner();

        TokenExtensionFacetData storage s = LibTokenExtensionFacet.tokenExtensionFacetStorage();

        _removeExtensionFunctions(extension);
    }

    function _registerExtensionFunctions(address extensionAddress) internal {
        IERC20Extension extension = IERC20Extension(extensionAddress);

        //First register the function selectors with the diamond
        bytes4[] memory externalFunctions = extension.externalFunctions();

        if (externalFunctions.length > 0) {
            IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
            cut[0] = IDiamondCut.FacetCut({
                facetAddress: extensionAddress, 
                action: IDiamondCut.FacetCutAction.Add, 
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
            IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
            cut[0] = IDiamondCut.FacetCut({
                facetAddress: extensionAddress, 
                action: IDiamondCut.FacetCutAction.Remove, 
                functionSelectors: externalFunctions
            });

            //Dont call initalize when removing functions
            LibDiamond.diamondCut(cut, address(0), "");
        }
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external override view returns (uint256) {
        TokenExtensionFacetData storage s = LibTokenExtensionFacet.tokenExtensionFacetStorage();
        return ERC20CoreFaucet(s.erc20Core).totalSupply();
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external override view returns (uint256) {
        TokenExtensionFacetData storage s = LibTokenExtensionFacet.tokenExtensionFacetStorage();
        return ERC20CoreFaucet(s.erc20Core).balanceOf(account);
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external override view returns (uint256) {
        //bytes memory result = invokeCore(abi.encodeWithSelector(IERC20.allowance.selector, owner, spender));
        return 0;
        //return uint256(result);
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        //TODO Extensions

        return invokeCore(abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount))[0] == 0x01;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        //TODO Extensions

        return invokeCore(abi.encodeWithSelector(IERC20.approve.selector, spender, amount))[0] == 0x01;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        //TODO Extensions

        return invokeCore(abi.encodeWithSelector(IERC20.transferFrom.selector, sender, recipient, amount))[0] == 0x01;
    }

    function invokeCore(bytes memory _calldata) internal returns (bytes memory) {
        TokenExtensionFacetData storage s = LibTokenExtensionFacet.tokenExtensionFacetStorage();
        (bool success, bytes memory data) = s.erc20Core.delegatecall(_calldata);
        if (!success) {
            if (data.length > 0) {
                // bubble up the error
                revert(string(data));
            } else {
                revert("TokenExtensionFacet: delegatecall to ERC20Core reverted");
            }
        }

        return data;
    }
}

