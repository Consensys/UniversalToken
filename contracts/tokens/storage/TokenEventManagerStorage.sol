pragma solidity ^0.8.0;

import {TransferData} from "../../extensions/IExtension.sol";

abstract contract TokenEventManagerStorage {
    
    bytes32 constant internal EVENT_MANAGER_DATA_SLOT = keccak256("token.transferdata.events");

    struct ExtensionListeningCache {
        bool listening;
        uint256 listenIndex;
    }

    struct SavedCallbackFunction {
        address callbackAddress;
        bytes4 callbackSelector;
    }

    struct EventManagerData {
        uint256 eventFiringStack;
        mapping(address => bytes32[]) eventListForExtensions;
        mapping(address => mapping(bytes32 => ExtensionListeningCache)) listeningCache;
        mapping(bytes32 => SavedCallbackFunction[]) listeners;
        mapping(bytes32 => bool) isFiring;
    }

    function eventManagerData() internal pure returns (EventManagerData storage ds) {
        bytes32 position = EVENT_MANAGER_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    
    function _on(bytes32 eventId, function (TransferData memory) external returns (bool) callback) internal {
        _on(eventId, callback.address, callback.selector);
    }

    function _on(bytes32 eventId, address callbackAddress, bytes4 callbackSelector) internal {
        EventManagerData storage emd = eventManagerData();

        require(!emd.listeningCache[callbackAddress][eventId].listening, "Address already listening for event");

        uint256 eventIndex = emd.listeners[eventId].length;
        
        emd.listeners[eventId].push(SavedCallbackFunction(
                callbackAddress,
                callbackSelector
            )
        );

        ExtensionListeningCache storage elc = emd.listeningCache[callbackAddress][eventId];
        elc.listening = true;
        elc.listenIndex = eventIndex;

        emd.eventListForExtensions[callbackAddress].push(eventId);
    }

    /**
    * @dev Use this function to clear all listeners for a given extension. The extension will have
    * to invoke _on again to listen for events again.
    */
    function _clearListeners(address extension) internal {
        EventManagerData storage emd = eventManagerData();

        bytes32[] storage eventIds = emd.eventListForExtensions[extension];

        for (uint i = 0; i < eventIds.length; i++) {
            bytes32 eventId = eventIds[i];

            // To prevent a gap in the listener array, we store the last callback in the index of the callback to delete, and
            // then delete the last slot (swap and pop).
            uint256 lastCallbackIndex = emd.listeners[eventId].length - 1;
            uint256 callbackIndex = emd.listeningCache[extension][eventId].listenIndex;

            // When the callback to delete is the callback, the swap operation is unnecessary. However, since this occurs so
            // rarely that we still do the swap here to avoid the gas cost of adding
            // an 'if' statement
            SavedCallbackFunction storage lastCallback = emd.listeners[eventId][lastCallbackIndex];

            emd.listeners[eventId][callbackIndex] = lastCallback;
            emd.listeningCache[lastCallback.callbackAddress][eventId].listenIndex = callbackIndex;

            delete emd.listeningCache[extension][eventId];
            emd.listeners[eventId].pop();
        }

        delete emd.eventListForExtensions[extension];
    }
}