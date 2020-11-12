/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";


/**
 * @title LimiterRole
 * @dev Limiters are responsible for limiting token operations.
 */
contract LimiterRole {
    using Roles for Roles.Role;

    event LimiterAdded(address indexed token, address indexed account);
    event LimiterRemoved(address indexed token, address indexed account);

    // Mapping from token to token limiters.
    mapping(address => Roles.Role) private _limiters;

    constructor () internal {}

    modifier onlyLimiter(address token) {
        require(isLimiter(token, msg.sender));
        _;
    }

    function isLimiter(address token, address account) public view returns (bool) {
        return _limiters[token].has(account);
    }

    function addLimiter(address token, address account) public onlyLimiter(token) {
        _addLimiter(token, account);
    }

    function removeLimiter(address token, address account) public onlyLimiter(token) {
        _removeLimiter(token, account);
    }

    function renounceLimiter(address token) public {
        _removeLimiter(token, msg.sender);
    }

    function _addLimiter(address token, address account) internal {
        _limiters[token].add(account);
        emit LimiterAdded(token, account);
    }

    function _removeLimiter(address token, address account) internal {
        _limiters[token].remove(account);
        emit LimiterRemoved(token, account);
    }
}