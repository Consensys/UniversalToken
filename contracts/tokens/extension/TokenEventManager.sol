pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/utils/ContextUpgradeable.sol";
import {TransferData} from "../../interface/IExtension.sol";
import {ExtensionRegistrationStorage} from "./ExtensionRegistrationStorage.sol";
import {TokenEventManagerStorage} from "./TokenEventManagerStorage.sol";

/**
* @title Token Event Manager
* @notice A contract implementation of an on-chain event manager specifically
* for the TransferData data structure.
* @dev This is extended by TokenExtension and TokenLogic to both trigger and listen
* to events with a given event id. To listen for an event id, use the _on(eventId, callback) 
* or external on(eventId, callback) functions. The eventId parameter is a bytes32, the
* callback parameter is the type function (TransferData memory) external returns (bool).
*
* To trigger an event, use the internal _trigger(eventId, eventData) function. The eventId
* parameter is a bytes32 and should match what is passed to eventId for in on/_on function.
* The eventData is type TransferData and is passed to each callback invoked.
* Currently, only enabled registered extensions are invoked if they listen for a 
* given eventId. If the extension listens for an eventId but is disabled, it is
* not triggered.
* 
* TODO To make this contract generic in the future when Solidity eventually supports
* generic types, simply replace TransferData with type T and replace the callback
* type with function (T memory) external returns (bool)
*/
abstract contract TokenEventManager is TokenEventManagerStorage, ExtensionRegistrationStorage {
    
    function _extensionState(address ext) internal view returns (ExtensionState) {
        return _addressToExtensionData(ext).state;
    }

    function _trigger(bytes32 eventId, TransferData memory data) internal {
        EventManagerData storage emd = eventManagerData();

        SavedCallbackFunction[] storage callbacks = emd.listeners[eventId];
        
        require(!emd.isFiring[eventId], "Recursive trigger not allowed");
        
        emd.eventFiringStack++;
        emd.isFiring[eventId] = true;


        for (uint i = 0; i < callbacks.length; i++) {
            bytes4 listenerFuncSelector = callbacks[i].callbackSelector;
            address listenerAddress = callbacks[i].callbackAddress;

            if (_extensionState(listenerAddress) == ExtensionState.EXTENSION_DISABLED) {
                continue; //Skip disabled extensions
            }

            bytes memory cdata = abi.encodePacked(abi.encodeWithSelector(listenerFuncSelector, data), listenerAddress);

            (bool success, bytes memory result) = listenerAddress.delegatecall{gas: gasleft()}(cdata);

            require(success, string(result));
        }

        emd.isFiring[eventId] = false;
        emd.eventFiringStack--;
    }
}