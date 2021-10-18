pragma solidity ^0.8.0;

import {Roles} from "../../../roles/Roles.sol";

library AllowBlockLib {
    using Roles for Roles.Role;

    bytes32 constant ALLOWLIST_ROLE = keccak256("allowblock.roles.allowlisted");
    bytes32 constant BLOCKLIST_ROLE = keccak256("allowblock.roles.blocklisted");
    bytes32 constant ALLOWLIST_ADMIN_ROLE = keccak256("allowblock.roles.allowlisted.admin");
    bytes32 constant BLOCKLIST_ADMIN_ROLE = keccak256("allowblock.roles.blocklisted.admin");

    function isAllowlisted(address account) internal view returns (bool) {
        return Roles.roleStorage(ALLOWLIST_ROLE).has(account);
    }
    
    function addAllowlisted(address account) internal {
        Roles.roleStorage(ALLOWLIST_ROLE).add(account);
    }

    function removeAllowlisited(address account) internal {
        Roles.roleStorage(ALLOWLIST_ROLE).remove(account);
    }

    function isAllowlistedAdmin(address account) internal view returns (bool) {
        return Roles.roleStorage(ALLOWLIST_ADMIN_ROLE).has(account);
    }
    
    function addAllowlistedAdmin(address account) internal {
        Roles.roleStorage(ALLOWLIST_ADMIN_ROLE).add(account);
    }

    function removeAllowlisitedAdmin(address account) internal {
        Roles.roleStorage(ALLOWLIST_ADMIN_ROLE).remove(account);
    }

    function isBlocklisted(address account) internal view returns (bool) {
        return Roles.roleStorage(BLOCKLIST_ROLE).has(account);
    }

    function addBlocklisted(address account) internal {
        Roles.roleStorage(BLOCKLIST_ROLE).add(account);
    }

    function removeBlocklisted(address account) internal {
        Roles.roleStorage(BLOCKLIST_ROLE).remove(account);
    }

    function isBlocklistedAdmin(address account) internal view returns (bool) {
        return Roles.roleStorage(BLOCKLIST_ADMIN_ROLE).has(account);
    }

    function addBlocklistedAdmin(address account) internal {
        Roles.roleStorage(BLOCKLIST_ADMIN_ROLE).add(account);
    }

    function removeBlocklistedAdmin(address account) internal {
        Roles.roleStorage(BLOCKLIST_ADMIN_ROLE).remove(account);
    }
}