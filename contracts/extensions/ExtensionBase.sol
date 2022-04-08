pragma solidity ^0.8.0;

import {TokenStandard} from "../interface/IExtension.sol";
import {ContextUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/utils/ContextUpgradeable.sol";
import {StorageSlotUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/utils/StorageSlotUpgradeable.sol";
import {ITokenLogic} from "../tokens/logic/ITokenLogic.sol";

/**
* @title Extension Base Contract
* @notice This shouldn't be used directly, it should be extended by child contracts
* @dev This contract setups the base of every Extension contract (including proxies). It
* defines a set data structure for holding important information about the current Extension
* registration instance. This includes the current Token address, the current Extension
* global address and an "authorized caller" (callsite).
*
* The _msgSender() function is also defined and should be used instead of the msg.sender variable.
*  _msgSender() has a different behavior depending on who the msg.sender variable is, 
* this is to allow meta-transactions
*
* The "callsite" can be used to support meta transactions through a trusted forwarder. Currently
* not implemented
*
* The ExtensionBase also provides several function modifiers to restrict function
* invokation
*/
abstract contract ExtensionBase is ContextUpgradeable {

    function _logicAddress() internal view returns (address) {
        bytes32 EIP1967_LOCATION = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
        
        //Update EIP1967 Storage Slot
        return StorageSlotUpgradeable.getAddressSlot(EIP1967_LOCATION).value;
    }

    /**
    * @dev The current Extension logic contract address
    */
    function _extensionAddress() internal pure returns (address ret) {
        if (msg.data.length >= 24) {
            // At this point we know that the sender is a token proxy,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            ret = address(0);
        }
    }

    /**
    * @dev The current token address that registered this extension instance
    */
    function _tokenAddress() internal view returns (address payable) {
        return payable(this); //we are the token address
    }

    /**
    * @dev A function modifier to only allow a function only used for events to be
    * guarded by ensuring that the function is only invoked if we are the token.
    * This ensures that only a delegatecall to this function from the token address
    * is valid
    */
    modifier eventGuard {
        require(address(this) == _tokenAddress(), "Token: Unauthorized");
        _;
    }

    receive() external payable {}
}