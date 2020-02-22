pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";
import "./BlacklistAdminRole.sol";

/**
 * @title BlacklistedRole
 * @dev Blacklisted accounts have been forbidden by a BlacklistAdmin to perform certain actions (e.g. participate in a
 * crowdsale). This role is special in that the only accounts that can add it are BlacklistAdmins (who can also remove
 * it), and not Blacklisteds themselves.
 */
contract BlacklistedRole is BlacklistAdminRole {
    using Roles for Roles.Role;

    event BlacklistedAdded(address indexed account);
    event BlacklistedRemoved(address indexed account);

    Roles.Role private _blacklisteds;

    modifier onlyNotBlacklisted() {
        require(!isBlacklisted(msg.sender));
        _;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisteds.has(account);
    }

    function addBlacklisted(address account) public onlyBlacklistAdmin {
        _addBlacklisted(account);
    }

    function removeBlacklisted(address account) public onlyBlacklistAdmin {
        _removeBlacklisted(account);
    }

    function _addBlacklisted(address account) internal {
        _blacklisteds.add(account);
        emit BlacklistedAdded(account);
    }

    function _removeBlacklisted(address account) internal {
        _blacklisteds.remove(account);
        emit BlacklistedRemoved(account);
    }
}
