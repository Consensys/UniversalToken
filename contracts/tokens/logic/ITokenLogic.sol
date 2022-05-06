pragma solidity ^0.8.0;

import {IToken} from "../IToken.sol";

/**
* @title Token Logic Interface
* @dev An interface that all Token Logic contracts should implement
*/
interface ITokenLogic is IToken {
    function initialize(bytes memory data) external;
}