pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/utils/ContextUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {TransferData} from "..//IToken.sol";

/**
* @title Base Contract for Extendable contracts
* @notice This is an abstract contract that should only be used by other
* contracts in this folder
* @dev This is the base contract that will be extended by all 
* Extendable contracts. Provides _msgSender() functions through
* the ContextUpgradeable contract
*/
abstract contract ExtendableBase is ContextUpgradeable {
    /**
    * @dev The storage slot that will hold the MappedExtensions struct
    */
    bytes32 constant MAPPED_EXTENSION_STORAGE_SLOT = keccak256("erc20.core.storage.address");

    /**
    * @dev A state of all possible registered extension states
    * A registered extension can either not exist, be enabled or disabled
    */
    enum ExtensionState {
        EXTENSION_NOT_EXISTS,
        EXTENSION_ENABLED,
        EXTENSION_DISABLED
    }

    /**
    * @dev Registered extension data
    * @param state The current state of this registered extension
    * @param index The current index of this registered extension in registeredExtensions array
    * @param executeContext The current address this extension will be executed in
    */
    struct ExtensionData {
        ExtensionState state;
        uint256 index;
        address executeContext;
        bytes4[] externalFunctions;
    }

    /**
    * @dev All Registered extensions + additional mappings for easy lookup
    * @param registeredExtensions An array of all registered extensions, both enabled and disabled extensions
    * @param funcToExtension A mapping of function selector to global extension address
    * @param extensions A mapping of global extension address to ExtensionData
    */
    struct MappedExtensions {
        address[] registeredExtensions;
        mapping(bytes4 => address) funcToExtension;
        mapping(address => ExtensionData) extensions;
    }

    /**
    * @dev Get the MappedExtensions data stored inside this contract.
    * @return ds The MappedExtensions struct stored in this contract
    */
    function _extensionStorage() internal pure returns (MappedExtensions storage ds) {
        bytes32 position = MAPPED_EXTENSION_STORAGE_SLOT;
        assembly {
            ds.slot := position
        }
    }

    /**
    * @dev Obtain data about an extension address in the form of the ExtensionData struct.
    * @param extension The extension address to lookup
    * @return ExtensionData Data about the extension in the form of the ExtensionData struct
    */
    function _addressToExtensionData(address extension) internal view returns (ExtensionData memory) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        return extLibStorage.extensions[extension];
    }

    function _extensionState(address ext) internal view returns (ExtensionState) {
        return _addressToExtensionData(ext).state;
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
    * @dev Get the full ExtensionData of the extension that registered the provided
    * function selector, even if the extension is currently disabled. 
    * If no extension registered the given function selector, then a blank ExtensionData is returned.
    * @param funcSig The function signature to lookup
    * @return ExtensionData Returns the full ExtensionData of the extension that registered the
    * provided function selector
    */
    function _functionToExtensionData(bytes4 funcSig) internal view returns (ExtensionData storage) {
        MappedExtensions storage extLibStorage = _extensionStorage();

        require(extLibStorage.funcToExtension[funcSig] != address(0), "Unknown function");

        return extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];
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

        require(extData.state == ExtensionState.EXTENSION_ENABLED, "The extension must be enabled");

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

        require(extData.state == ExtensionState.EXTENSION_DISABLED, "The extension must be enabled");

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
        MappedExtensions storage extLibStorage = _extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state != ExtensionState.EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

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
    }
}