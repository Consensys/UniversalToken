pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ProxyContext is Context {
    bytes32 constant PROXY_CONTEXT_DATA_SLOT = keccak256("proxy.context.data");
    bytes32 constant MSG_SENDER_SLOT = keccak256("proxy.context.data.msgsender");
    
    struct ProxyContextData {
        address callsite;
    }

    function _setCallSite(address callsite) internal {
        ProxyContextData storage ds = _proxyContextData();
        ds.callsite = callsite;
    }

    function _proxyContextData() pure internal returns (ProxyContextData storage ds) {
        bytes32 position = PROXY_CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function _callsiteAddress() internal view returns (address) {
        ProxyContextData storage ds = _proxyContextData();
        return ds.callsite;
    }

    
    modifier onlyCallsite {
        require(msg.sender == _callsiteAddress(), "Unauthorized");
        _;
    }
    
    function _msgSender() internal virtual view override returns (address ret) {
        if (msg.data.length >= 24 && msg.sender == _callsiteAddress()) {
            // At this point we know that the sender is a token proxy,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {  
            return super._msgSender();
        }
    }

/*     function _staticcall(address implementation) internal view {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := staticcall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    } */

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
}