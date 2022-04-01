pragma solidity ^0.8.0;

import {TokenStandard} from "../tokens/IToken.sol";

/**
* @title Extension Metadata Interface
* @dev An interface that extensions must implement that provides additional
* metadata about the extension. 
*/
interface IExtensionMetadata {
    /**
    * @notice An array of function signatures this extension adds when
    * registered when a TokenProxy
    * @dev This function is used by the TokenProxy to determine what
    * function selectors to add to the TokenProxy
    */
    function externalFunctions() external view returns (bytes4[] memory);
    
    /**
    * @notice An array of role IDs that this extension requires from the Token
    * in order to function properly
    * @dev This function is used by the TokenProxy to determine what
    * roles to grant to the extension after registration and what roles to remove
    * when removing the extension
    */
    function requiredRoles() external view returns (bytes32[] memory);

    /**
    * @notice Whether a given Token standard is supported by this Extension
    * @param standard The standard to check support for
    */
    function isTokenStandardSupported(TokenStandard standard) external view returns (bool);

    /**
    * @notice The address that deployed this extension.
    */
    function extensionDeployer() external view returns (address);

    /**
    * @notice The hash of the package string this extension was deployed with
    */
    function packageHash() external view returns (bytes32);

    /**
    * @notice The version of this extension, represented as a number
    */
    function version() external view returns (uint256);

    /**
    * @notice The ERC1820 interface label the extension will be registered as in the ERC1820 registry
    */
    function interfaceLabel() external view returns (string memory);
}