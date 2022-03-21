pragma solidity ^0.8.0;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ExtensionBase {
    bytes32 constant PROXY_DATA_SLOT = keccak256("ext.proxy.data");
    bytes32 constant MSG_SENDER_SLOT = keccak256("ext.proxy.data.msgsender");

    struct ProxyData {
        address token;
        address extension;
        address callsite;
        bool initialized;
    }

    function _proxyData() internal pure returns (ProxyData storage ds) {
        bytes32 position = PROXY_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function _extensionAddress() internal view returns (address) {
        ProxyData storage ds = _proxyData();
        return ds.extension;
    }

    function _tokenAddress() internal view returns (address payable) {
        ProxyData storage ds = _proxyData();
        return payable(ds.token);
    }

    function _authorizedCaller() internal view returns (address) {
        ProxyData storage ds = _proxyData();
        return ds.callsite;
    }

    modifier onlyToken {
        require(msg.sender == _tokenAddress(), "Token: Unauthorized");
        _;
    }

    modifier onlyAuthorizedCaller {
        require(msg.sender == _authorizedCaller(), "Caller: Unauthorized");
        _;
    }

    modifier onlyAuthorizedCallerOrExtension {
        require(msg.sender == _authorizedCaller() || msg.sender == _extensionAddress(), "Caller: Unauthorized");
        _;
    }

    modifier onlyAuthorizedCallerOrSelf {
        require(msg.sender == _authorizedCaller() || msg.sender == address(this), "Caller: Unauthorized");
        _;
    }

    function _msgSender() internal view returns (address) {
        return StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value;
    }

    receive() external payable {}
}