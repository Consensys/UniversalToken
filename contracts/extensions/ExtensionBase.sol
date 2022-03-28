pragma solidity ^0.8.0;

import {TokenStandard} from "../interface/IExtension.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

/**
* @title Extension Base Contract
* @notice This shouldn't be used directly, it should be extended by child contracts
* @dev This contract setups the base of every Extension contract (including proxies). It
* defines a set data structure for holding important information about the current Extension
* registration instance. This includes the current Token address, the current Extension
* global address and an "authorized caller" (callsite).
*
* The ExtensionBase also defines a _msgSender() function, this function should be used
* instead of the msg.sender variable. _msgSender() has a different behavior depending
* on who the msg.sender variable is, this is to allow both meta-transactions and 
* proxy forwarding
*
* The "callsite" should be considered an admin-style address. See
* ExtensionProxy for more information
*
* The ExtensionBase also provides several function modifiers to restrict function
* invokation
*/
abstract contract ExtensionBase is ContextUpgradeable {
    bytes32 constant PROXY_DATA_SLOT = keccak256("ext.proxy.data");
    bytes32 constant MSG_SENDER_SLOT = keccak256("ext.proxy.data.msgsender");

    /**
    * @dev Considered the storage to be shared between the proxy
    * and extension logic contract.
    * We share this information with the logic contract because it may
    * be useful for the logic contract to query this information
    * @param token The token address that registered this extension instance
    * @param extension The extension logic contract to use
    * @param callsite The "admin" of this registered extension instance
    * @param initialized Whether this instance is initialized
    */
    struct ProxyData {
        address token;
        address extension;
        address callsite;
        bool initialized;
        TokenStandard standard;
    }

    /**
    * @dev The ProxyData struct stored in this registered Extension instance.
    */
    function _proxyData() internal pure returns (ProxyData storage ds) {
        bytes32 position = PROXY_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    /**
    * @dev The current Extension logic contract address
    */
    function _extensionAddress() internal view returns (address) {
        ProxyData storage ds = _proxyData();
        return ds.extension;
    }

    /**
    * @dev The current token address that registered this extension instance
    */
    function _tokenAddress() internal view returns (address payable) {
        ProxyData storage ds = _proxyData();
        return payable(ds.token);
    }

    /**
    * @dev The current admin address for this registered extension instance
    */
    function _authorizedCaller() internal view returns (address) {
        ProxyData storage ds = _proxyData();
        return ds.callsite;
    }

    /**
    * @dev A function modifier to only allow the registered token to execute this function
    */
    modifier onlyToken {
        require(msg.sender == _tokenAddress(), "Token: Unauthorized");
        _;
    }

    /**
    * @dev A function modifier to only allow the admin to execute this function
    */
    modifier onlyAuthorizedCaller {
        require(msg.sender == _authorizedCaller(), "Caller: Unauthorized");
        _;
    }

    /**
    * @dev A function modifier to only allow the admin or ourselves to execute this function
    */
    modifier onlyAuthorizedCallerOrSelf {
        require(msg.sender == _authorizedCaller() || msg.sender == address(this), "Caller: Unauthorized");
        _;
    }

    /**
    * @dev Get the current msg.sender for the current CALL context
    */
    function _msgSender() internal virtual override view returns (address ret) {
        if (msg.data.length >= 24 && msg.sender == _authorizedCaller()) {
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

    receive() external payable {}
}