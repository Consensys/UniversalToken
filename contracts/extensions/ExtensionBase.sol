pragma solidity ^0.8.0;

abstract contract ExtensionBase {
    bytes32 constant CONTEXT_DATA_SLOT = keccak256("ext.context.data");

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
}