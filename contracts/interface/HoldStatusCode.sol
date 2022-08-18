// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

enum HoldStatusCode {
    Nonexistent,
    Ordered,
    Executed,
    ExecutedAndKeptOpen,
    ReleasedByNotary,
    ReleasedByPayee,
    ReleasedOnExpiration
}