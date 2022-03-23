pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {TransferData} from "..//IToken.sol";
import {ExtensionProxy} from "../../extensions/ExtensionProxy.sol";

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
    * @param extProxy The current extProxy address this extension should be executed in
    */
    struct ExtensionData {
        ExtensionState state;
        uint256 index;
        address extProxy;
        bytes4[] externalFunctions;
    }

    /**
    * @dev All Registered extensions + additional mappings for easy lookup
    * @param registeredExtensions An array of all registered extensions, both enabled and disabled extensions
    * @param funcToExtension A mapping of function selector to global extension address
    * @param extensions A mapping of global extension address to ExtensionData
    * @param proxyCache A mapping of deployed extension proxy addresses to global extension addresses
    */
    struct MappedExtensions {
        address[] registeredExtensions;
        mapping(bytes4 => address) funcToExtension;
        mapping(address => ExtensionData) extensions;
        mapping(address => address) proxyCache;
    }

    /**
    * @dev Get the MappedExtensions data stored inside this contract.
    * @return ds The MappedExtensions struct stored in this contract
    */
    function extensionStorage() private pure returns (MappedExtensions storage ds) {
        bytes32 position = MAPPED_EXTENSION_STORAGE_SLOT;
        assembly {
            ds.slot := position
        }
    }

    /**
    * @dev Obtain data about an extension address in the form of the ExtensionData struct. The
    * address provided can be either the global extension address or the deployed extension proxy address
    * @param ext The extension address to lookup, either the global extension address or the deployed extension proxy address
    * @return ExtensionData Data about the extension in the form of the ExtensionData struct
    */
    function _addressToExtensionData(address ext) internal view returns (ExtensionData memory) {
        MappedExtensions storage extLibStorage = extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);
        return extLibStorage.extensions[extension];
    }

    /**
    * @dev Determine if the given extension address is active (registered & enabled). The provided
    * extension address can either be the global extension address or the extension proxy address.
    * @return bool True if the provided extension address is registered & enabled, otherwise false.
    */
    function _isActiveExtension(address ext) internal view returns (bool) {
        MappedExtensions storage extLibStorage = extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);
        return extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_ENABLED;
    }

    /**
    * @dev Register an extension at the given global extension address. This will
    * deploy a new ExtensionProxy contract to act as the extension proxy and register
    * all function selectors the extension exposes.
    * This will also invoke the initialize function on the extension proxy, to do this 
    * we must know who the current caller is.
    * Registering an extension automatically enables it for use.
    *
    * @param extension The global extension address to register
    * @param token The token address that will be using this extension
    * @param caller The current caller that will be initalizing the extension proxy
    */
    function _registerExtension(address extension, address token, address caller) internal returns (bool) {
        MappedExtensions storage extLibStorage = extensionStorage();
        require(extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_NOT_EXISTS, "The extension must not already exist");

        //TODO Register with 1820
        //Interfaces has been validated, lets begin setup

        //Next we need to deploy the ExtensionProxy contract
        //To sandbox our extension's storage
        ExtensionProxy extProxy = new ExtensionProxy(token, extension, address(this));

        //Next lets figure out what external functions to register in the Extension
        bytes4[] memory externalFunctions = extProxy.externalFunctions();

        //If we have external functions to register, then lets register them
        if (externalFunctions.length > 0) {
            for (uint i = 0; i < externalFunctions.length; i++) {
                bytes4 func = externalFunctions[i];
                require(extLibStorage.funcToExtension[func] == address(0), "Function signature conflict");
                //STATICCALLMAGIC not allowed
                require(func != hex"ffffffff", "Invalid function signature");

                extLibStorage.funcToExtension[func] = extension;
            }
        }

        //Initialize the new extension proxy
        extProxy.prepareCall(caller);
        extProxy.initialize();

        //Finally, add it to storage
        extLibStorage.extensions[extension] = ExtensionData(
            ExtensionState.EXTENSION_ENABLED,
            extLibStorage.registeredExtensions.length,
            address(extProxy),
            externalFunctions
        );

        extLibStorage.registeredExtensions.push(extension);
        extLibStorage.proxyCache[address(extProxy)] = extension;

        return true;
    }

    /**
    * @dev Get the deployed extension proxy address that registered the provided
    * function selector. If no extension registered the given function selector,
    * then return address(0). If the extension that registered the function selector is disabled,
    * then the address(0) is returned
    * @param funcSig The function signature to lookup
    * @return address Returns the deployed enabled extension proxy address that registered the
    * provided function selector, otherwise address(0)
    */
    function _functionToExtensionProxyAddress(bytes4 funcSig) internal view returns (address) {
        MappedExtensions storage extLibStorage = extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];

        //Only return an address for an extension that is enabled
        if (extData.state == ExtensionState.EXTENSION_ENABLED) {
            return extData.extProxy;
        }

        return address(0);
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
        MappedExtensions storage extLibStorage = extensionStorage();

        require(extLibStorage.funcToExtension[funcSig] != address(0), "Unknown function");

        return extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];
    }

    /**
    * @dev Disable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Disabling the extension keeps the extension + storage live but simply disables
    * all registered functions and transfer events
    *
    * @param ext Either the global extension address or the deployed extension proxy address to disable
    */
    function _disableExtension(address ext) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_ENABLED, "The extension must be enabled");

        extData.state = ExtensionState.EXTENSION_DISABLED;
        extLibStorage.proxyCache[extData.extProxy] = address(0);
    }

    /**
    * @dev Enable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param ext Either the global extension address or the deployed extension proxy address to enable
    */
    function _enableExtension(address ext) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_DISABLED, "The extension must be enabled");

        extData.state = ExtensionState.EXTENSION_ENABLED;
        extLibStorage.proxyCache[extData.extProxy] = extension;
    }

    /**
    * @dev Check whether a given address is a deployed extension proxy address that
    * is registered.
    *
    * @param callsite The address to check
    */
    function _isExtensionProxyAddress(address callsite) internal view returns (bool) {
        MappedExtensions storage extLibStorage = extensionStorage();

        return extLibStorage.proxyCache[callsite] != address(0);
    }

    /**
    * @dev Get an array of all global extension addresses that have been registered, regardless of if they are
    * enabled or disabled
    */
    function _allExtensionsRegistered() internal view returns (address[] storage) {
        MappedExtensions storage extLibStorage = extensionStorage();
        return extLibStorage.registeredExtensions;
    }

    /**
    * @dev Get an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled
    */
    function _allExtensionProxies() internal view returns (address[] memory) {
        MappedExtensions storage extLibStorage = extensionStorage();
        address[] storage globalAddresses = extLibStorage.registeredExtensions;
        address[] memory proxyAddresses = new address[](globalAddresses.length);

        for (uint i = 0; i < proxyAddresses.length; i++) {
            proxyAddresses[i] = _proxyAddressForExtension(globalAddresses[i]);
        }

        return proxyAddresses;
    }

    /**
    * @dev Get the deployed extension proxy address given a global extension address. 
    * This function assumes the given global extension address has been registered using
    *  _registerExtension.
    * @param extension The global extension address to convert
    */
    function _proxyAddressForExtension(address extension) internal view returns (address) {
        MappedExtensions storage extLibStorage = extensionStorage();
        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state != ExtensionState.EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

        return extData.extProxy;
    }

    /**
    * @dev Remove the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Removing an extension deletes all data about the deployed extension proxy address
    * and makes the extension's storage inaccessable forever.
    *
    * @param ext Either the global extension address or the deployed extension proxy address to remove
    */
    function _removeExtension(address ext) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);

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

        extLibStorage.proxyCache[extData.extProxy] = address(0);
        delete extLibStorage.extensions[extension];
        extLibStorage.registeredExtensions.pop();
    }

    /**
    * @dev If the providen address is the deployed extension proxy, then convert it to the
    * global extension address. Otherwise, return what was given 
    */
    function __forceGlobalExtensionAddress(address extension) private view returns (address) {
        MappedExtensions storage extLibStorage = extensionStorage();
        if (extLibStorage.proxyCache[extension] != address(0)) {
            return extLibStorage.proxyCache[extension];
        }

        return extension; //nothing to do
    }

    /**
    * @dev Go through each extension, if it's enabled execute the implemented function and pass the extension
    * If any invokation of the implemented function given an extension returns false, halt and return false
    * If they all return true (or there are no extensions), then return true
    * @param toInvoke The function that should be invoked with each enabled extension
    * @param data The current data that will be passed to the implemented function along with the enabled extension address
    * @return bool True if all extensions were executed successfully, false if any extension returned false
    */
    function _executeOnAllExtensions(function (address, TransferData memory) internal returns (bool) toInvoke, TransferData memory data) internal returns (bool) {
        MappedExtensions storage extLibData = extensionStorage();

        for (uint i = 0; i < extLibData.registeredExtensions.length; i++) {
            address extension = extLibData.registeredExtensions[i];

            ExtensionData memory extData = extLibData.extensions[extension]; 

            if (extData.state == ExtensionState.EXTENSION_DISABLED) {
                continue; //Skip if the extension is disabled
            }

            //Execute the implemented function using the enabled extension
            //however, execute the call at the ExtensionProxy contract address
            //The ExtensionProxy contract will delegatecall the extension logic
            //and manage storage/api
            address proxy = extData.extProxy;
            bool result = toInvoke(proxy, data);
            if (!result) {
                return false;
            }
        }

        return true;
    }
}