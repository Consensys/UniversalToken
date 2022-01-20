pragma solidity ^0.8.0;

import {Diamond, LibDiamond} from "../proxy/diamond/Diamond.sol";
import {IExtension} from "./IExtension.sol";
import {ExtensionBase} from "./ExtensionBase.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ExtensionStorage is ExtensionBase, Diamond {
    constructor(address token, address extension) {
        //Setup context data
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }
        
        //First grab and register functions in diamond
        IExtension ext = IExtension(extension);
        bytes4[] memory allExternalFunctions = ext.externalFunctions();

        if (allExternalFunctions.length > 0) {
            LibDiamond.FacetCut[] memory cut = new LibDiamond.FacetCut[](1);
            cut[0] = LibDiamond.FacetCut({
                facetAddress: extension, 
                action: LibDiamond.FacetCutAction.Add, 
                functionSelectors: allExternalFunctions
            });
            LibDiamond.diamondCut(cut, extension, abi.encodeWithSelector(IExtension.initalize.selector));
        }

        ds.token = token;
        ds.extension = extension;
    }

    function prepareCall(address caller, bytes4 func) external onlyToken {
        StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value = caller;

        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }

        ds.diamondFunctions[func] = true;
    }

    fallback() external override payable onlyToken {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }

        if (ds.diamondFunctions[msg.sig]) {
            _delegateCallFunction(msg.sig);
            ds.diamondFunctions[msg.sig] = false;
        } else {
            _delegate(ds.extension);
        }
    }

    function initalize() external onlyToken {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }

        ds.initalized = true;
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

    function externalFunctions() external view returns (bytes4[] memory) {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }
        
        IExtension ext = IExtension(ds.extension);

        return ext.externalFunctions();
    }

    function requiredRoles() external view returns (bytes32[] memory) {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }
        
        IExtension ext = IExtension(ds.extension);

        return ext.requiredRoles();
    }
}