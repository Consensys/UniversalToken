pragma solidity ^0.8.0;

interface IExtension {
    function initalize() external;

    function externalFunctions() external view returns (bytes4[] memory);
}