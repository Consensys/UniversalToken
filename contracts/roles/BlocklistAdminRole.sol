// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "./Roles.sol";


/**
 * @title BlocklistAdminRole
 * @dev BlocklistAdmins are responsible for assigning and removing Blocklisted accounts.
 */
abstract contract BlocklistAdminRole {
    using Roles for Roles.Role;

    event BlocklistAdminAdded(address indexed token, address indexed account);
    event BlocklistAdminRemoved(address indexed token, address indexed account);

    // Mapping from token to token blocklist admins.
    mapping(address => Roles.Role) private _blocklistAdmins;

    modifier onlyBlocklistAdmin(address token) virtual {
        require(isBlocklistAdmin(token, msg.sender));
        _;
    }

    function isBlocklistAdmin(address token, address account) public view returns (bool) {
        return _blocklistAdmins[token].has(account);
    }

    function addBlocklistAdmin(address token, address account) public onlyBlocklistAdmin(token) {
        _addBlocklistAdmin(token, account);
    }

    function removeBlocklistAdmin(address token, address account) public onlyBlocklistAdmin(token) {
        _removeBlocklistAdmin(token, account);
    }

    function renounceBlocklistAdmin(address token) public {
        _removeBlocklistAdmin(token, msg.sender);
    }

    function _addBlocklistAdmin(address token, address account) internal {
        _blocklistAdmins[token].add(account);
        emit BlocklistAdminAdded(token, account);
    }

    function _removeBlocklistAdmin(address token, address account) internal {
        _blocklistAdmins[token].remove(account);
        emit BlocklistAdminRemoved(token, account);
    }
}