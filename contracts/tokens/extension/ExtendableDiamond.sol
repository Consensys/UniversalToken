pragma solidity ^0.8.0;

import {TokenEventManagerStorage} from "./TokenEventManagerStorage.sol";
import {IExtension, TransferData} from "../../interface/IExtension.sol";
import {ExtensionRegistrationStorage} from "./ExtensionRegistrationStorage.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {IDiamondCut} from "../../diamond/interfaces/IDiamondCut.sol";
import {IToken, TokenStandard} from "../IToken.sol";
import "../../diamond/libraries/LibDiamond.sol";
import "../../diamond/interfaces/IDiamondLoupe.sol";
import "../../diamond/interfaces/IDiamondCut.sol";
import "../../diamond/interfaces/IERC173.sol";
import "../../diamond/interfaces/IERC165.sol";
import '../../helpers/Errors.sol';

/**
* @title Router contract for Extensions
* @notice This should be inherited by token proxy contracts
* @dev ExtendableDiamond provides internal functions to manage
* extensions, view extension data and invoke extension functions
* (if the current call is an extension function) through the Diamond EIP
*/
contract ExtendableDiamond is TokenEventManagerStorage, ExtensionRegistrationStorage, IDiamondLoupe, IERC165 {

    constructor() payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Facet {
    //     address facetAddress;
    //     bytes4[] functionSelectors;
    // }

    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external override view returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external override view returns (bytes4[] memory facetFunctionSelectors_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external override view returns (address[] memory facetAddresses_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external override view returns (address facetAddress_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId) external override view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.supportedInterfaces[_interfaceId];
    }

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
        require(extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_NOT_EXISTS, Errors.EXTENSION_ALREADY_EXISTS);

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
        bytes memory initCalldata = abi.encodePacked(abi.encodeWithSelector(IExtension.initialize.selector), extension);
        LibDiamond.diamondCut(_diamondCut, extension, initCalldata);

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

    function _upgradeExtension(address extension, address newExtension) internal returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        require(extLibStorage.extensions[extension].state != ExtensionState.EXTENSION_NOT_EXISTS, Errors.EXTENSION_DOESNT_EXISTS);

        IExtension ext = IExtension(extension);
        IExtension newExt = IExtension(newExtension);

        address currentDeployer = ext.extensionDeployer();
        address newDeployer = newExt.extensionDeployer();

        require(currentDeployer == newDeployer, Errors.DEPLOYERS_DONT_MATCH);

        bytes32 currentPackageHash = ext.packageHash();
        bytes32 newPackageHash = newExt.packageHash();

        require(currentPackageHash == newPackageHash, Errors.PACKAGE_HASH_DONT_MATCH);

        uint256 currentVersion = ext.version();
        uint256 newVersion = newExt.version();

        require(currentVersion != newVersion, Errors.VERSION_DONT_MATCH);

        TokenStandard standard = IToken(address(this)).tokenStandard();

        require(ext.isTokenStandardSupported(standard), Errors.SW_TOKEN_STANDARD_NOT_SUPPORTED);

        bytes32 interfaceLabel = keccak256(abi.encodePacked(ext.interfaceLabel()));
        bytes32 newInterfaceLabel = keccak256(abi.encodePacked(newExt.interfaceLabel()));

        require(interfaceLabel == newInterfaceLabel, Errors.INTERFACE_LABELS_DONT_MATCH);
        
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
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address extension = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(_isActiveExtension(extension), Errors.EXTENSION_DISABLED);

        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), Errors.DIAMOND_NO_FUNCTION);

        bytes memory finalData = abi.encodePacked(msg.data, facet);

        assembly {
            let result := delegatecall(sub(gas(), 5000), facet, add(finalData, 0x20), mload(finalData), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
    * @dev Determine if the given extension address is active (registered & enabled).
    * @param extension Check if a given extension address is active
    * @return bool True if the provided extension address is registered & enabled, otherwise false.
    */
    function _isActiveExtension(address extension) internal view returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        return extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_ENABLED;
    }

    /**
    * @dev Disable the extension at the provided address.
    *
    * Disabling the extension keeps the extension + storage live but simply disables
    * all registered functions and transfer events
    *
    * @param extension The extension address to disable. This does not remove the extension
    */
    function _disableExtension(address extension) internal {
        MappedExtensions storage extLibStorage = _extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_ENABLED, Errors.EXTENSION_DISABLED);

        extData.state = ExtensionState.EXTENSION_DISABLED;
    }

    /**
    * @dev Enable the extension at the provided address.
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param extension The extension address to enable
    */
    function _enableExtension(address extension) internal {
        MappedExtensions storage extLibStorage = _extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_DISABLED, Errors.EXTENSION_ENABLED);

        extData.state = ExtensionState.EXTENSION_ENABLED;
    }

    /**
    * @dev Get an array of all global extension addresses that have been registered, regardless of if they are
    * enabled or disabled
    */
    function _allExtensionsRegistered() internal view returns (address[] storage) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        return extLibStorage.registeredExtensions;
    }

    /**
    * @dev Remove the extension at the provided address.
    *
    * Removing an extension deletes all data about the deployed extension proxy address
    * and makes the extension's storage inaccessable forever.
    *
    * @param extension The extension address to remove
    */
    function _removeExtension(address extension) internal virtual {
        IExtension ext = IExtension(extension);

        bytes4[] memory externalFunctions = ext.externalFunctions();

        IDiamondCut.FacetCut[] memory _diamondCut = new IDiamondCut.FacetCut[](1);
        _diamondCut[0] = IDiamondCut.FacetCut(
            address(0),
            IDiamondCut.FacetCutAction.Remove,
            externalFunctions
        );
        LibDiamond.diamondCut(_diamondCut, address(0), "");

        MappedExtensions storage extLibStorage = _extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state != ExtensionState.EXTENSION_NOT_EXISTS, Errors.EXTENSION_DOESNT_EXISTS);

        // To prevent a gap in the extensions array, we store the last extension in the index of the extension to delete, and
        // then delete the last slot (swap and pop).
        uint256 lastExtensionIndex = extLibStorage.registeredExtensions.length - 1;
        uint256 extensionIndex = extData.index;

        // When the extension to delete is the last extension, the swap operation is unnecessary. However, since this occurs so
        // rarely that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement
        address lastExtension = extLibStorage.registeredExtensions[lastExtensionIndex];

        extLibStorage.registeredExtensions[extensionIndex] = lastExtension;
        extLibStorage.extensions[lastExtension].index = extensionIndex;

        delete extLibStorage.extensions[extension];
        extLibStorage.registeredExtensions.pop();

        _clearListeners(extension);
    }

    
    /**
    * @dev Use this function to clear all listeners for a given extension. The extension will have
    * to invoke _on again to listen for events again.
    */
    function _clearListeners(address extension) internal {
        EventManagerData storage emd = eventManagerData();

        bytes32[] storage eventIds = emd.eventListForExtensions[extension];

        for (uint i = 0; i < eventIds.length; i++) {
            bytes32 eventId = eventIds[i];

            // To prevent a gap in the listener array, we store the last callback in the index of the callback to delete, and
            // then delete the last slot (swap and pop).
            uint256 lastCallbackIndex = emd.listeners[eventId].length - 1;
            uint256 callbackIndex = emd.listeningCache[extension][eventId].listenIndex;

            // When the callback to delete is the callback, the swap operation is unnecessary. However, since this occurs so
            // rarely that we still do the swap here to avoid the gas cost of adding
            // an 'if' statement
            SavedCallbackFunction storage lastCallback = emd.listeners[eventId][lastCallbackIndex];

            emd.listeners[eventId][callbackIndex] = lastCallback;
            emd.listeningCache[lastCallback.callbackAddress][eventId].listenIndex = callbackIndex;

            delete emd.listeningCache[extension][eventId];
            emd.listeners[eventId].pop();
        }

        delete emd.eventListForExtensions[extension];
    }
}