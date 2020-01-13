pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";
/**
 * @title BlacklistAdminRole
 * @dev BlacklistAdmins are responsible for assigning and removing Blacklisted accounts.
 */
contract BlacklistAdminRole {
    using Roles for Roles.Role;

    event BlacklistAdminAdded(address indexed account);
    event BlacklistAdminRemoved(address indexed account);

    Roles.Role private _blacklistAdmins;

    constructor () internal {
        _addBlacklistAdmin(msg.sender);
    }

    modifier onlyBlacklistAdmin() {
        require(isBlacklistAdmin(msg.sender));
        _;
    }

    function isBlacklistAdmin(address account) public view returns (bool) {
        return _blacklistAdmins.has(account);
    }

    function addBlacklistAdmin(address account) public onlyBlacklistAdmin {
        _addBlacklistAdmin(account);
    }

    function renounceBlacklistAdmin() public {
        _removeBlacklistAdmin(msg.sender);
    }

    function _addBlacklistAdmin(address account) internal {
        _blacklistAdmins.add(account);
        emit BlacklistAdminAdded(account);
    }

    function _removeBlacklistAdmin(address account) internal {
        _blacklistAdmins.remove(account);
        emit BlacklistAdminRemoved(account);
    }
}