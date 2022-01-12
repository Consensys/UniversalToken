pragma solidity ^0.8.0;

interface IProxyContext {
    function prepareLogicCall(address caller) external;
    function prepareExtCall(address caller) external;
}