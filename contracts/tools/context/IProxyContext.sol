pragma solidity ^0.8.0;

interface IProxyContext {
    function prepareCall(address caller) external;
}