// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HoldStatusCode.sol";

struct ERC20HoldData {
    address sender;
    address recipient;
    address notary;
    uint256 amount;
    uint256 expirationDateTime;
    bytes32 secretHash;
    HoldStatusCode status;
}

/**
 * @title Holdable ERC20 Token Interface.
 * @dev like approve except the tokens can't be spent by the sender while they are on hold.
 */
interface IERC20HoldableToken is IERC20 {

    event NewHold(
        bytes32 indexed holdId,
        address indexed recipient,
        address indexed notary,
        uint256 amount,
        uint256 expirationDateTime,
        bytes32 lockHash
    );
    event ExecutedHold(
        bytes32 indexed holdId,
        bytes32 lockPreimage,
        address recipient
    );
    event ReleaseHold(bytes32 indexed holdId, address sender);

    /**
     @notice Called by the sender to hold some tokens for a recipient that the sender can not release back to themself until after the expiration date.
     @param holdId a unique identifier for the hold.
     @param recipient optional account the tokens will be transferred to on execution. If a zero address, the recipient must be specified on execution of the hold.
     @param notary account that can execute the hold. Typically the recipient but can be a third party or a smart contact.
     @param amount of tokens to be transferred to the recipient on execution. Must be a non zero amount.
     @param expirationDateTime UNIX epoch seconds the held amount can be released back to the sender by the sender. Past dates are allowed.
     @param lockHash optional keccak256 hash of a lock preimage. An empty hash will not enforce the hash lock when the hold is executed.
     */
    function hold(
        bytes32 holdId,
        address recipient,
        address notary,
        uint256 amount,
        uint256 expirationDateTime,
        bytes32 lockHash
    ) external;

    function retrieveHoldData(bytes32 holdId) external view returns (ERC20HoldData memory);

    /**
     @notice Called by the notary to transfer the held tokens to the set at the hold recipient if there is no hash lock.
     @param holdId a unique identifier for the hold.
     */
    function executeHold(bytes32 holdId) external;

    /**
     @notice Called by the notary to transfer the held tokens to the recipient that was set at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a keccak256 hash
     */
    function executeHold(bytes32 holdId, bytes32 lockPreimage) external;

    /**
     @notice Called by the notary to transfer the held tokens to the recipient if no recipient was specified at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a keccak256 hash
     @param recipient the account the tokens will be transferred to on execution.
     */
    function executeHold(
        bytes32 holdId,
        bytes32 lockPreimage,
        address recipient
    ) external;

    /**
     @notice Called by the notary at any time or the sender after the expiration date to release the held tokens back to the sender.
     @param holdId a unique identifier for the hold.
     */
    function releaseHold(bytes32 holdId) external;

    /**
     @notice Amount of tokens owned by an account that are held pending execution or release.
     @param account owner of the tokens
     */
    function balanceOnHold(address account) external view returns (uint256);

    /**
     @notice Total amount of tokens owned by an account including all the held tokens pending execution or release.
     @param account owner of the tokens
     */
    function spendableBalanceOf(address account) external view returns (uint256);

    function totalSupplyOnHold() external view returns (uint256);

    /**
     @param holdId a unique identifier for the hold.
     @return hold status code.
     */
    function holdStatus(bytes32 holdId) external view returns (HoldStatusCode);
}
