pragma solidity ^0.8.0;

import {IToken} from "../tokens/IToken.sol";
import {IExtensionStorage} from "./IExtensionStorage.sol";
import {IExtension} from "./IExtension.sol";
import {IExtensionMetadata, TokenStandard} from "./IExtensionMetadata.sol";
import {ExtensionBase} from "./ExtensionBase.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ExtensionStorage is IExtensionStorage, IExtensionMetadata, ExtensionBase {
    constructor(address token, address extension, address callsite) {
        //Setup context data
        ContextData storage ds = _contextData();

        ds.token = token;
        ds.extension = extension;
        ds.callsite = callsite;
        
        //Ensure we support this token standard
        TokenStandard standard = IToken(token).tokenStandard();

        require(isTokenStandardSupported(standard), "Extension does not support token standard");
    }

    function prepareCall(address caller) external override onlyCallsite {
        StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value = caller;
    }

    fallback() external payable onlyCallsiteOrSelf {
        ContextData storage ds = _contextData();

        _delegate(ds.extension);
    }

    function initialize() external onlyCallsite {
        ContextData storage ds = _contextData();

        ds.initialized = true;

        //now forward initalization to the extension
        _delegate(ds.extension);
    }

    /**
    * @dev Delegates execution to an implementation contract.
    * This is a low level function that doesn't return to its internal call site.
    * It will return to the external caller whatever the implementation returns.
    * @param implementation Address to delegate.
    */
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function externalFunctions() external override view returns (bytes4[] memory) {
        ContextData storage ds = _contextData();
        
        IExtension ext = IExtension(ds.extension);

        return ext.externalFunctions();
    }

    function requiredRoles() external override view returns (bytes32[] memory) {
        ContextData storage ds = _contextData();
        
        IExtension ext = IExtension(ds.extension);

        return ext.requiredRoles();
    }

    function isTokenStandardSupported(TokenStandard standard) public override view returns (bool) {
        ContextData storage ds = _contextData();
        
        IExtension ext = IExtension(ds.extension);

        return ext.isTokenStandardSupported(standard);
    }
}