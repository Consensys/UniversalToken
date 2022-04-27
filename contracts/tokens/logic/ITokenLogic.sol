pragma solidity ^0.8.0;

import {IToken} from "../IToken.sol";
import {IExternalFunctionLookup} from "../../interface/IExternalFunctionLookup.sol";

/**
* @title Token Logic Interface
* @dev An interface that all Token Logic contracts should implement
*/
interface ITokenLogic is IToken, IExternalFunctionLookup {
    function initialize(bytes memory data) external;
}