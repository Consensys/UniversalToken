pragma solidity ^0.8.0;

abstract contract TokenEventConstants {
    bytes32 constant TOKEN_TRANSFER_EVENT = keccak256("token.events.transfer");
    bytes32 constant TOKEN_APPROVE_EVENT = keccak256("token.events.transfer");
}