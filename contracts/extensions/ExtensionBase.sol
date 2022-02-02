pragma solidity ^0.8.0;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ExtensionBase {
    bytes32 constant CONTEXT_DATA_SLOT = keccak256("ext.context.data");
    bytes32 constant MSG_SENDER_SLOT = keccak256("ext.context.data.msgsender");

    struct ContextData {
        address token;
        address extension;
        mapping(bytes4 => bool) diamondFunctions;
        bool initalized;
    }

    function _extensionAddress() internal view returns (address) {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }

        return ds.extension;
    }

    function _tokenAddress() internal view returns (address) {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }

        return ds.token;
    }

    modifier onlyToken {
        require(msg.sender == _tokenAddress(), "Unauthorized");
        _;
    }

    function _msgSender() internal view returns (address) {
        return StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value;
    }

    function _delegateCallFunction(bytes4 funcSig) internal {
        address facet = _extensionAddress();
        require(facet != address(0), "Diamond: Function does not exist");

        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}