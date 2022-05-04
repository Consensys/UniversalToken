pragma solidity ^0.8.0;

import {TransferData} from "../IToken.sol";

interface ITokenEventManager {
    struct SavedCallbackFunction {
        function (TransferData memory) external returns (bool) func;
    }

    function on(bytes32 eventId, function (TransferData memory) external returns (bool) callback) external;
}