
/**
* @title Extension Registration Storage
* @notice Internal functions and definations to access extension registration on the current
* token
* @dev This contract should be inherited from any other contract (include extensions/facets) that
* wish to access the extensions registered. For the sake of contract size, this is intentionally left
* very minimal.
*/
abstract contract ExtensionRegistrationStorage {
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
}