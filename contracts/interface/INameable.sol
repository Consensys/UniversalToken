pragma solidity ^0.8.0;

interface INameable {
    function name() external view returns (string memory);
}