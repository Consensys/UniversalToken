pragma solidity ^0.8.0;

interface IHelloWorldExtension {
    function resetCounter() external;

    function viewTransactionCount() external view returns (uint256);
}