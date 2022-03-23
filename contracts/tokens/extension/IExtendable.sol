pragma solidity ^0.8.0;

/**
* @title IExtendable
* @notice Interface for token proxy that offers extensions
*/
interface IExtendable {
    /**
    * @dev Register the extension at the given global extension address. This will deploy a new
    * ExtensionStorage contract to act as a proxy. The extension's proxy will
    * be initalized and all functions the extension has will be registered
    *
    * @param extension The deployed extension address to register
    */
    function registerExtension(address extension) external;

    /**
    * @dev Remove the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Removing an extension deletes all data about the deployed extension proxy address
    * and makes the extension's storage inaccessable forever.
    *
    * @param extension Either the global extension address or the deployed extension proxy address to remove
    */
    function removeExtension(address extension) external;

    /**
    * @dev Disable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Disabling the extension keeps the extension + storage live but simply disables
    * all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to disable
    */
    function disableExtension(address extension) external;

    /**
    * @dev Enable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to enable
    */
    function enableExtension(address extension) external;

    /**
    * @dev Get an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled
    */
    function allExtensionsRegistered() external view returns (address[] memory);

    /**
    * @dev Get an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled
    */
    function allExtensionProxies() external view returns (address[] memory);

    /**
    * @dev Get the deployed extension proxy address given a global extension address. 
    * This function assumes the given global extension address has been registered using
    *  _registerExtension.
    * @param extension The global extension address to convert
    */
    function proxyAddressForExtension(address extension) external view returns (address);
}