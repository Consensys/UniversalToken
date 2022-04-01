pragma solidity ^0.8.0;

import {IExtension, TransferData} from "../../interface/IExtension.sol";
import {ExtendableBase} from "./ExtendableBase.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {IDiamondCut} from "../../diamond/interfaces/IDiamondCut.sol";
import {Diamond} from "../../diamond/Diamond.sol";
import {IToken, TokenStandard} from "../IToken.sol";

/**
* @title Router contract for Extensions
* @notice This should be inherited by token proxy contracts
* @dev ExtendableDiamond provides internal functions to manage
* extensions, view extension data and invoke extension functions
* (if the current call is an extension function) through the Diamond EIP
*/
contract ExtendableDiamond is ExtendableBase, Diamond {

    /**
    * @dev Register an extension at the given global extension address. This will create a new
    * DiamondCut with the extension address being the facet. All external functions the extension
    * exposes will be registered with the DiamondCut. The DiamondCut will be initalized by calling
    * the initialize function on the extension through delegatecall
    * Registering an extension automatically enables it for use.
    *
    * @param extension The global extension address to register as a Diamond facet
    */
    function _registerExtension(address extension) internal virtual returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        require(extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_NOT_EXISTS, "The extension must not already exist");

        //Interfaces has been validated, lets begin setup

        IExtension ext = IExtension(extension);

        //Next lets figure out what external functions to register in the Extension
        bytes4[] memory externalFunctions = ext.externalFunctions();

        IDiamondCut.FacetCut[] memory _diamondCut = new IDiamondCut.FacetCut[](1);
        _diamondCut[0] = IDiamondCut.FacetCut(
            extension,
            IDiamondCut.FacetCutAction.Add,
            externalFunctions
        );
        LibDiamond.diamondCut(_diamondCut, extension, abi.encodeWithSelector(IExtension.initialize.selector));

        //Finally, add it to storage
        extLibStorage.extensions[extension] = ExtensionData(
            ExtensionState.EXTENSION_ENABLED,
            extLibStorage.registeredExtensions.length,
            address(this),
            externalFunctions
        );

        extLibStorage.registeredExtensions.push(extension);



        return true;
    }

    function _removeExtension(address extension) internal override virtual {
        IExtension ext = IExtension(extension);

        bytes4[] memory externalFunctions = ext.externalFunctions();

        IDiamondCut.FacetCut[] memory _diamondCut = new IDiamondCut.FacetCut[](1);
        _diamondCut[0] = IDiamondCut.FacetCut(
            address(0),
            IDiamondCut.FacetCutAction.Remove,
            externalFunctions
        );
        LibDiamond.diamondCut(_diamondCut, address(0), "");

        super._removeExtension(extension);
    }

    function _upgradeExtension(address extension, address newExtension) internal returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        require(extLibStorage.extensions[extension].state != ExtensionState.EXTENSION_NOT_EXISTS, "The extension must already exist");

        IExtension ext = IExtension(extension);
        IExtension newExt = IExtension(newExtension);

        address currentDeployer = ext.extensionDeployer();
        address newDeployer = newExt.extensionDeployer();

        require(currentDeployer == newDeployer, "Deployer address for new extension is different than current");

        bytes32 currentPackageHash = ext.packageHash();
        bytes32 newPackageHash = newExt.packageHash();

        require(currentPackageHash == newPackageHash, "Package for new extension is different than current");

        uint256 currentVersion = ext.version();
        uint256 newVersion = newExt.version();

        require(currentVersion != newVersion, "Versions should not match");

        TokenStandard standard = IToken(address(this)).tokenStandard();

        require(ext.isTokenStandardSupported(standard), "Token standard is not supported in new extension");

        bytes32 interfaceLabel = keccak256(abi.encodePacked(ext.interfaceLabel()));
        bytes32 newInterfaceLabel = keccak256(abi.encodePacked(newExt.interfaceLabel()));

        require(interfaceLabel == newInterfaceLabel, "Interface labels do not match");
        
        _removeExtension(extension);

        _registerExtension(newExtension);

        return true;
    }

    /**
    * @dev Determine if a given function selector is registered by an enabled
    * deployed extension proxy address. If no extension proxy exists or if the
    * deployed extension proxy address is disabled, then false is returned
    *
    * @param funcSig The function selector to check
    * @return bool True if an enabled deployed extension proxy address has registered
    * the provided function selector, otherwise false.
    */
    function _isExtensionFunction(bytes4 funcSig) internal virtual view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        return ds.selectorToFacetAndPosition[funcSig].facetAddress != address(0);
    }

    /**
    * @dev Forward the current call to the proper deployed extension proxy address. This
    * function assumes the current function selector is registered by an enabled deployed extension proxy address.
    *
    * This call returns and exits the current call context.
    */
    function _invokeExtensionFunction() internal virtual {
        require(_isExtensionFunction(msg.sig), "No extension found with function signature");

        _callFacet(msg.sig);
    }
}