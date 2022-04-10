pragma solidity ^0.8.0;

import {TokenEventManagerStorage} from "./TokenEventManagerStorage.sol";
import {TransferData} from "../../interface/IExtension.sol";
import {TokenEventConstants} from "./TokenEventConstants.sol";

abstract contract TokenEventListener is TokenEventManagerStorage, TokenEventConstants {
        /**
    * @dev Listen for an event hash and invoke a given callback function. This callback function
    * will be invoked with the TransferData for the event.
    */
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
}