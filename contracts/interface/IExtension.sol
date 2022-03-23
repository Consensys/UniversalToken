pragma solidity ^0.8.0;

import {TransferData} from "../tokens/IToken.sol";
import {IExtensionMetadata, TokenStandard} from "./IExtensionMetadata.sol";

/**
* @title Extension Interface
* @dev An interface to be implemented by Extensions
*/
interface IExtension is IExtensionMetadata {
    /**
    * @notice This function cannot be invoked directly
    * @dev This function is invoked when the Extension is registered
    * with a TokenProxy 
    */
    function initialize() external;

    /**
    * @notice This function cannot be invoked directly
    * @dev This function is invoked right after a transfer occurs on the
    * Token.
    * @param data The information about the transfer that just occured as a TransferData struct
    */
    function onTransferExecuted(TransferData memory data) external returns (bool);
}