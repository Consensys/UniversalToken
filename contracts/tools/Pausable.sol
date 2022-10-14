// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../roles/PauserRole.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is PauserRole {
    event Paused(address indexed token, address account);
    event Unpaused(address indexed token, address account);

    // Mapping from token to token paused status.
    mapping(address => bool) private _paused;

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused(address token) public view returns (bool) {
        return _paused[token];
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused(address token) {
        require(!_paused[token]);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused(address token) {
        require(_paused[token]);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause(address token) public onlyPauser(token) whenNotPaused(token) {
        _paused[token] = true;
        emit Paused(token, msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause(address token) public onlyPauser(token) whenPaused(token) {
        _paused[token] = false;
        emit Unpaused(token, msg.sender);
    }
}
