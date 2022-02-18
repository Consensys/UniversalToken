pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {TransferData} from "../IToken.sol";
import {ExtensionStorage} from "../../extensions/ExtensionStorage.sol";

library ExtensionLib {
    bytes32 constant ERC20_EXTENSION_LIST_LOCATION = keccak256("erc20.core.storage.address");

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
    * @param context The current context address this extension should be executed in
    * @param ignoreReverts Whether reverts when executing this extension should be ignored
    */
    struct ExtensionData {
        ExtensionState state;
        uint256 index;
        address context;
    }

    struct MappedExtensions {
        address[] registeredExtensions;
        mapping(bytes4 => address) funcToExtension;
        mapping(address => ExtensionData) extensions;
        mapping(address => bool) contextCache;
    }

    function extensionStorage() private pure returns (MappedExtensions storage ds) {
        bytes32 position = ERC20_EXTENSION_LIST_LOCATION;
        assembly {
            ds.slot := position
        }
    }

    function _isActiveExtension(address extension) internal view returns (bool) {
        MappedExtensions storage extLibStorage = extensionStorage();
        return extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_ENABLED;
    }

    function _registerExtension(address extension, address token, address caller) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
        require(extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_NOT_EXISTS, "The extension must not already exist");

        //TODO Register with 1820
        //Interfaces has been validated, lets begin setup

        //Next we need to deploy the ExtensionStorage contract
        //To sandbox our extension's storage
        ExtensionStorage context = new ExtensionStorage(token, extension, address(this));

        //Next lets figure out what external functions to register in the Diamond
        bytes4[] memory externalFunctions = context.externalFunctions();

        //If we have external functions to register, then lets register them
        if (externalFunctions.length > 0) {
            for (uint i = 0; i < externalFunctions.length; i++) {
                bytes4 func = externalFunctions[i];
                require(extLibStorage.funcToExtension[func] == address(0), "Function signature conflict");

                extLibStorage.funcToExtension[func] = extension;
            }
        }

        //Initialize the new extension context
        context.prepareCall(caller);
        context.initialize();

        //Finally, add it to storage
        extLibStorage.extensions[extension] = ExtensionData(
            ExtensionState.EXTENSION_ENABLED,
            extLibStorage.registeredExtensions.length,
            address(context)
        );

        extLibStorage.registeredExtensions.push(extension);
        extLibStorage.contextCache[address(context)] = true;
    }

    function _functionToExtensionContextAddress(bytes4 funcSig) internal view returns (address) {
        MappedExtensions storage extLibStorage = extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];

        //Only return an address for an extension that is enabled
        if (extData.state == ExtensionState.EXTENSION_ENABLED) {
            return extData.context;
        }

        return address(0);
    }

    function _functionToExtensionData(bytes4 funcSig) internal view returns (ExtensionData storage) {
        MappedExtensions storage extLibStorage = extensionStorage();

        require(extLibStorage.funcToExtension[funcSig] != address(0), "Unknown function");

        return extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];
    }

    function _disableExtension(address extension) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_ENABLED, "The extension must be enabled");

        extData.state = ExtensionState.EXTENSION_DISABLED;
        extLibStorage.contextCache[extData.context] = false;
    }

    function _enableExtension(address extension) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_DISABLED, "The extension must be enabled");

        extData.state = ExtensionState.EXTENSION_ENABLED;
        extLibStorage.contextCache[extData.context] = true;
    }

    function _isContextAddress(address callsite) internal view returns (bool) {
        MappedExtensions storage extLibStorage = extensionStorage();

        return extLibStorage.contextCache[callsite];
    }

    function _allExtensions() internal view returns (address[] memory) {
        MappedExtensions storage extLibStorage = extensionStorage();
        return extLibStorage.registeredExtensions;
    }

    function _contextAddressForExtension(address extension) internal view returns (address) {
        MappedExtensions storage extLibStorage = extensionStorage();
        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state != ExtensionState.EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

        return extData.context;
    }

    function _removeExtension(address extension) internal {
        MappedExtensions storage extLibStorage = extensionStorage();
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

        extLibStorage.contextCache[extData.context] = false;
        delete extLibStorage.extensions[extension];
        extLibStorage.registeredExtensions.pop();
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
            //however, execute the call at the ExtensionStorage contract address
            //The ExtensionStorage contract will delegatecall the extension logic
            //and manage storage/api
            address context = extData.context;
            bool result = toInvoke(context, data);
            if (!result) {
                return false;
            }
        }

        return true;
    }
}