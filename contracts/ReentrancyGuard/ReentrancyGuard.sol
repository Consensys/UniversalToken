/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonMultiReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly multiple
     * times (more than twice).
     */
    modifier nonMultiReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter <= _guardCounter + 1);
    }
}