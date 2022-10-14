// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "./Roles.sol";
import "./AllowlistAdminRole.sol";


/**
 * @title AllowlistedRole
 * @dev Allowlisted accounts have been forbidden by a AllowlistAdmin to perform certain actions (e.g. participate in a
 * crowdsale). This role is special in that the only accounts that can add it are AllowlistAdmins (who can also remove
 * it), and not Allowlisteds themselves.
 */
abstract contract AllowlistedRole is AllowlistAdminRole {
    using Roles for Roles.Role;

    event AllowlistedAdded(address indexed token, address indexed account);
    event AllowlistedRemoved(address indexed token, address indexed account);

    // Mapping from token to token allowlisteds.
    mapping(address => Roles.Role) private _allowlisteds;

    modifier onlyNotAllowlisted(address token) {
        require(!isAllowlisted(token, msg.sender));
        _;
    }

    function isAllowlisted(address token, address account) public view returns (bool) {
        return _allowlisteds[token].has(account);
    }

    function addAllowlisted(address token, address account) public onlyAllowlistAdmin(token) {
        _addAllowlisted(token, account);
    }

    function removeAllowlisted(address token, address account) public onlyAllowlistAdmin(token) {
        _removeAllowlisted(token, account);
    }

    function _addAllowlisted(address token, address account) internal {
        _allowlisteds[token].add(account);
        emit AllowlistedAdded(token, account);
    }

    function _removeAllowlisted(address token, address account) internal {
        _allowlisteds[token].remove(account);
        emit AllowlistedRemoved(token, account);
    }
}
