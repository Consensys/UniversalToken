// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./HoldStatusCode.sol";

interface IHoldableERC1400TokenExtension {
    function executeHold(
        address token,
        bytes32 holdId,
        uint256 value,
        bytes32 lockPreimage
    ) external;

    function retrieveHoldData(address token, bytes32 holdId) external view returns (
        bytes32 partition,
        address sender,
        address recipient,
        address notary,
        uint256 value,
        uint256 expiration,
        bytes32 secretHash,
        bytes32 secret,
        HoldStatusCode status
    );
}