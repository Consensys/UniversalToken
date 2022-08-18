// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "./Roles.sol";


/**
 * @title AllowlistAdminRole
 * @dev AllowlistAdmins are responsible for assigning and removing Allowlisted accounts.
 */
abstract contract AllowlistAdminRole {
    using Roles for Roles.Role;

    event AllowlistAdminAdded(address indexed token, address indexed account);
    event AllowlistAdminRemoved(address indexed token, address indexed account);

    // Mapping from token to token allowlist admins.
    mapping(address => Roles.Role) private _allowlistAdmins;

    modifier onlyAllowlistAdmin(address token) virtual {
        require(isAllowlistAdmin(token, msg.sender));
        _;
    }

    function isAllowlistAdmin(address token, address account) public view returns (bool) {
        return _allowlistAdmins[token].has(account);
    }

    function addAllowlistAdmin(address token, address account) public onlyAllowlistAdmin(token) {
        _addAllowlistAdmin(token, account);
    }

    function removeAllowlistAdmin(address token, address account) public onlyAllowlistAdmin(token) {
        _removeAllowlistAdmin(token, account);
    }

    function renounceAllowlistAdmin(address token) public {
        _removeAllowlistAdmin(token, msg.sender);
    }

    function _addAllowlistAdmin(address token, address account) internal {
        _allowlistAdmins[token].add(account);
        emit AllowlistAdminAdded(token, account);
    }

    function _removeAllowlistAdmin(address token, address account) internal {
        _allowlistAdmins[token].remove(account);
        emit AllowlistAdminRemoved(token, account);
    }
}