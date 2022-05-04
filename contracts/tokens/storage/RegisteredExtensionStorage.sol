pragma solidity ^0.8.0;

abstract contract RegisteredExtensionStorage {
    /**
    * @dev The storage slot that will hold the MappedExtensions struct
    */
    bytes32 constant internal MAPPED_EXTENSION_STORAGE_SLOT = keccak256("erc20.core.storage.address");

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
    
    
    modifier onlyActiveExtension {
        require(_isActiveExtension(msg.sender), "Only active extensions can invoke");
        _;
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
    * @dev Determine if the given extension address is active (registered & enabled). The provided
    * extension address can either be the global extension address or the extension proxy address.
    * @return bool True if the provided extension address is registered & enabled, otherwise false.
    */
    function _isActiveExtension(address ext) internal view returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);
        return extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_ENABLED;
    }

    /**
    * @dev Obtain data about an extension address in the form of the ExtensionData struct. The
    * address provided can be either the global extension address or the deployed extension proxy address
    * @param ext The extension address to lookup, either the global extension address or the deployed extension proxy address
    * @return ExtensionData Data about the extension in the form of the ExtensionData struct
    */
    function _addressToExtensionData(address ext) internal view returns (ExtensionData memory) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);
        return extLibStorage.extensions[extension];
    }

    /**
    * @dev If the providen address is the deployed extension proxy, then convert it to the
    * global extension address. Otherwise, return what was given 
    */
    function __forceGlobalExtensionAddress(address extension) internal view returns (address) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        if (extLibStorage.proxyCache[extension] != address(0)) {
            return extLibStorage.proxyCache[extension];
        }

        return extension; //nothing to do
    }
}