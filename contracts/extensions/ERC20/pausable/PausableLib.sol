pragma solidity ^0.8.0;

import {Roles} from "../../../roles/Roles.sol";

library PausableLib {
    using Roles for Roles.Role;

    bytes32 constant PAUSE_DATA_SLOT = keccak256("pausable.pausedata");

    struct PauseData {
        bool isPaused;
        mapping(address => bool) pausedFor;
    }

    function pauseData() internal pure returns (PauseData storage ds) {
        bytes32 position = PAUSE_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function isPaused() internal view returns (bool) {
        return pauseData().isPaused;
    }

    function isPausedFor(address caller) internal view returns (bool) {
        return isPaused() || pauseData().pausedFor[caller];
    }

    function pause() internal {
        pauseData().isPaused = true;
    }

    function unpause() internal {
        pauseData().isPaused = false;
    }


}