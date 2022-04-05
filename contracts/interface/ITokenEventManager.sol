pragma solidity ^0.8.0;

import {TransferData} from "../tokens/IToken.sol";

interface ITokenEventManager {
    function on(bytes32 eventId, function (TransferData memory) external returns (bool) callback) external;
}