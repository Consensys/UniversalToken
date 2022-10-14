// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "./Roles.sol";
import "./BlocklistAdminRole.sol";


/**
 * @title BlocklistedRole
 * @dev Blocklisted accounts have been forbidden by a BlocklistAdmin to perform certain actions (e.g. participate in a
 * crowdsale). This role is special in that the only accounts that can add it are BlocklistAdmins (who can also remove
 * it), and not Blocklisteds themselves.
 */
abstract contract BlocklistedRole is BlocklistAdminRole {
    using Roles for Roles.Role;

    event BlocklistedAdded(address indexed token, address indexed account);
    event BlocklistedRemoved(address indexed token, address indexed account);

    // Mapping from token to token blocklisteds.
    mapping(address => Roles.Role) private _blocklisteds;

    modifier onlyNotBlocklisted(address token) {
        require(!isBlocklisted(token, msg.sender));
        _;
    }

    function isBlocklisted(address token, address account) public view returns (bool) {
        return _blocklisteds[token].has(account);
    }

    function addBlocklisted(address token, address account) public onlyBlocklistAdmin(token) {
        _addBlocklisted(token, account);
    }

    function removeBlocklisted(address token, address account) public onlyBlocklistAdmin(token) {
        _removeBlocklisted(token, account);
    }

    function _addBlocklisted(address token, address account) internal {
        _blocklisteds[token].add(account);
        emit BlocklistedAdded(token, account);
    }

    function _removeBlocklisted(address token, address account) internal {
        _blocklisteds[token].remove(account);
        emit BlocklistedRemoved(token, account);
    }
}
