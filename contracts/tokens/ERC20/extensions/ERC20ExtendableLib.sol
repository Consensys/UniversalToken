pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Extension} from "../../../extensions/ERC20/IERC20Extension.sol";
import {TransferData} from "../../../extensions/ERC20/IERC20Extension.sol";
import {ExtensionStorage} from "../../../extensions/ExtensionStorage.sol";
import {Diamond, LibDiamond} from "../../../proxy/diamond/Diamond.sol";


library ERC20ExtendableLib {
    bytes32 constant ERC20_EXTENSION_LIST_LOCATION = keccak256("erc20.core.storage.address");
    uint8 constant EXTENSION_NOT_EXISTS = 0;
    uint8 constant EXTENSION_ENABLED = 1;
    uint8 constant EXTENSION_DISABLED = 2;

    struct ERC20ExtendableData {
        address[] registeredExtensions;
        mapping(address => uint8) extensionStateCache;
        mapping(address => uint256) extensionIndexes;
        mapping(address => address) contextAddresses;
        mapping(address => bool) contextCache;
    }

    function extensionStorage() private pure returns (ERC20ExtendableData storage ds) {
        bytes32 position = ERC20_EXTENSION_LIST_LOCATION;
        assembly {
            ds.slot := position
        }
    }

    function _isActiveExtension(address extension) internal view returns (bool) {
        ERC20ExtendableData storage extensionData = extensionStorage();
        return extensionData.extensionStateCache[extension] == EXTENSION_ENABLED;
    }

    function _registerExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] == EXTENSION_NOT_EXISTS, "The extension must not already exist");

        //First we need to verify this is a valid contract
        IERC165 ext165 = IERC165(extension);
        
        require(ext165.supportsInterface(0x01ffc9a7), "The extension must support IERC165");
        require(ext165.supportsInterface(type(IERC20Extension).interfaceId), "The extension must support IERC20Extension interface");

        //Interface has been validated, lets begin setup

        //Next we need to deploy the ExtensionStorage contract
        //To sandbox our extension's storage
        ExtensionStorage context = new ExtensionStorage(address(this), extension);

        //Next lets figure out what external functions to register in the Diamond
        bytes4[] memory externalFunctions = context.externalFunctions();

        //If we have external functions to register, then lets register them
        if (externalFunctions.length > 0) {
            LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
            cut[0] = LibDiamond.FacetCut({
                facetAddress: address(context), //Use the context address as the facet address
                action: LibDiamond.FacetCutAction.Add, 
                functionSelectors: externalFunctions
            });
            //We dont need to initalize anything
            LibDiamond.diamondCut(cut, address(0), "");
        }

        //Initalize the new extension context
        context.initalize();

        //Finally, add it to storage
        extensionData.extensionIndexes[extension] = extensionData.registeredExtensions.length;
        extensionData.registeredExtensions.push(extension);
        extensionData.extensionStateCache[extension] = EXTENSION_ENABLED;
        extensionData.contextAddresses[extension] = address(context);
        extensionData.contextCache[address(context)] = true;
    }

    function _disableExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] == EXTENSION_ENABLED, "The extension must be enabled");

        extensionData.extensionStateCache[extension] = EXTENSION_DISABLED;
        extensionData.contextCache[extensionData.contextAddresses[extension]] = false;
    }

    function _enableExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] == EXTENSION_DISABLED, "The extension must be enabled");

        extensionData.extensionStateCache[extension] = EXTENSION_ENABLED;
        extensionData.contextCache[extensionData.contextAddresses[extension]] = true;
    }

    function _isContextAddress(address callsite) internal view returns (bool) {
        ERC20ExtendableData storage extensionData = extensionStorage();

        return extensionData.contextCache[callsite];
    }

    function _allExtensions() internal view returns (address[] memory) {
        ERC20ExtendableData storage extensionData = extensionStorage();
        return extensionData.registeredExtensions;
    }

    function _removeExtension(address extension) internal {
        ERC20ExtendableData storage extensionData = extensionStorage();
        require(extensionData.extensionStateCache[extension] != EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

        // To prevent a gap in the extensions array, we store the last extension in the index of the extension to delete, and
        // then delete the last slot (swap and pop).
        uint256 lastExtensionIndex = extensionData.registeredExtensions.length - 1;
        uint256 extensionIndex = extensionData.extensionIndexes[extension];

        // When the extension to delete is the last extension, the swap operation is unnecessary. However, since this occurs so
        // rarely that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement
        address lastExtension = extensionData.registeredExtensions[lastExtensionIndex];

        extensionData.registeredExtensions[extensionIndex] = lastExtension;
        extensionData.extensionIndexes[lastExtension] = extensionIndex;

        delete extensionData.extensionIndexes[extension];
        extensionData.registeredExtensions.pop();

        extensionData.extensionStateCache[extension] = EXTENSION_NOT_EXISTS;
        extensionData.contextCache[extensionData.contextAddresses[extension]] = false;
        extensionData.contextAddresses[extension] = address(0);
    }

    function _invokeExtensionDelegateCall(address extension, bytes memory _calldata) private returns (bool) {
        address ext = address(extension);
        (bool success, bytes memory data) = ext.delegatecall(_calldata);
        if (!success) {
            if (data.length > 0) {
                // bubble up the error
                revert(string(data));
            } else {
                revert("ERC20ExtendableLib: delegatecall to extension reverted");
            }
        }

        return data[0] == 0x01;
    }

    function _validateTransfer(TransferData memory data) internal returns (bool) {
        //Go through each extension, if it's enabled execute the validate function
        //If any extension returns false, halt and return false
        //If they all return true (or there are no extensions), then return true

        ERC20ExtendableData storage extensionData = extensionStorage();

        for (uint i = 0; i < extensionData.registeredExtensions.length; i++) {
            address extension = extensionData.registeredExtensions[i];

            if (extensionData.extensionStateCache[extension] == EXTENSION_DISABLED) {
                continue; //Skip if the extension is disabled
            }

            //Execute the validate function using the proper interface
            //however, execute the call at the ExtensionStorage contract address
            //The ExtensionStorage contract will delegatecall the extension logic
            //and manage storage/api
            address context = extensionData.contextAddresses[extension];
            IERC20Extension ext = IERC20Extension(context);

            if (!ext.validateTransfer(data)) {
                return false;
            }
        }

        return true;
    }

    function _executeAfterTransfer(TransferData memory data) internal returns (bool) {
        //Go through each extension, if it's enabled execute the onTransferExecuted function
        //If any extension returns false, halt and return false
        //If they all return true (or there are no extensions), then return true

        ERC20ExtendableData storage extensionData = extensionStorage();

        for (uint i = 0; i < extensionData.registeredExtensions.length; i++) {
            address extension = extensionData.registeredExtensions[i];

            if (extensionData.extensionStateCache[extension] == EXTENSION_DISABLED) {
                continue; //Skip if the extension is disabled
            }

            //Execute the validate function using the proper interface
            //however, execute the call at the ExtensionStorage contract address
            //The ExtensionStorage contract will delegatecall the extension logic
            //and manage storage/api
            address context = extensionData.contextAddresses[extension];
            IERC20Extension ext = IERC20Extension(context);

            if (!ext.onTransferExecuted(data)) {
                return false;
            }
        }

        return true;
    }
}