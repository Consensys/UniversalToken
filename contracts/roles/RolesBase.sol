pragma solidity ^0.8.0;

import {Roles} from "./Roles.sol";

abstract contract RolesBase {
    using Roles for Roles.Role;
    
    function hasRole(address caller, bytes32 roleId) public view returns (bool) {
        return Roles.roleStorage(roleId).has(caller);
    }

    function _addRole(address caller, bytes32 roleId) internal {
        Roles.roleStorage(roleId).add(caller);
    }

    function _removeRole(address caller, bytes32 roleId) internal {
        Roles.roleStorage(roleId).remove(caller);
    }
}