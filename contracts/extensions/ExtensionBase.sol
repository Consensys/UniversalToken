pragma solidity ^0.8.0;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ExtensionBase {
    bytes32 constant CONTEXT_DATA_SLOT = keccak256("ext.context.data");
    bytes32 constant MSG_SENDER_SLOT = keccak256("ext.context.data.msgsender");

    struct ContextData {
        address token;
        address extension;
        bool initalized;
    }

    function _contextData() internal pure returns (ContextData storage ds) {
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function _extensionAddress() internal view returns (address) {
        ContextData storage ds = _contextData();
        return ds.extension;
    }

    function _tokenAddress() internal view returns (address) {
        ContextData storage ds = _contextData();
        return ds.token;
    }

    modifier onlyToken {
        require(msg.sender == _tokenAddress(), "Unauthorized");
        _;
    }

    function _msgSender() internal view returns (address) {
        return StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value;
    }

    receive() external payable {}
}