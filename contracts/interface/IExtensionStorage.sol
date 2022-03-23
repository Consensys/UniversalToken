pragma solidity ^0.8.0;

/**
* @title Extension Proxy Interface
* @dev An interface to interact with the Extension Proxy
*/
interface IExtensionStorage { 
    /**
    * @notice Cannot be called directly, can only be invoked by the TokenProxy
    * @dev This call notifies the Extension Proxy who the current caller will be
    */
    function prepareCall(address caller) external;
}