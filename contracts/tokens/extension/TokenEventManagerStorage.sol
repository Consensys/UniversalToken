
import {IExtension, TransferData} from "../../interface/IExtension.sol";

abstract contract TokenEventManagerStorage {
    bytes32 constant EVENT_MANAGER_DATA_SLOT = keccak256("token.transferdata.events");
    
    struct ExtensionListeningCache {
        bool listening;
        uint256 listenIndex;
    }

    struct SavedCallbackFunction {
        function (TransferData memory) external returns (bool) func;
    }

    struct EventManagerData {
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
}