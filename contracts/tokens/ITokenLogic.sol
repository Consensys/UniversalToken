pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";

interface ITokenLogic is IToken {
    function initialize(bytes memory data) external;
}