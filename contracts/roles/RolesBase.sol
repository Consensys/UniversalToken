pragma solidity ^0.8.0;

import {Roles} from "./Roles.sol";

/**
* @title Roles API
* @dev This base smart contract is resposible for managing roles 
* and offer internal functions for adding/removing roles from
* an address.
* Roles are denotted by a hashed string that hold a mapping of
* address => bool
* To avoid storage slot conflicts, the hashed string provided is
* concatted with "roles.storage." internally.
* The storage for roles is handled by the Roles library
*/
abstract contract RolesBase {
    using Roles for Roles.Role;

    event RoleAdded(address indexed caller, bytes32 indexed roleId);
    event RoleRemoved(address indexed caller, bytes32 indexed roleId);

    /**
    * @notice Whether the given caller address has the provided role id
    * @param caller The address to check if roleId is assigned 
    * @param roleId the role id to lookup for the given caller
    */
    function hasRole(address caller, bytes32 roleId) public view returns (bool) {
        return Roles.role(roleId).has(caller);
    }

    /**
    * @dev Add a roleId to the given caller address or do nothing
    * if the caller already has the role
    * This will not revert if the address already has the role
    * @param caller The address to assign the roleId to 
    * @param roleId the roleId to assign to the given caller
    */
    function _addRoleOrIgnore(address caller, bytes32 roleId) internal {
        if (Roles.role(roleId).has(caller)) {
            return;
        }

        _addRole(caller, roleId);
    }

    /**
    * @dev Add a roleId to the given caller address
    * This will revert if the address already has the role
    * The RoleAdded event is emitted 
    * @param caller The address to assign the roleId to 
    * @param roleId the roleId to assign to the given caller
    */
    function _addRole(address caller, bytes32 roleId) internal {
        Roles.role(roleId).add(caller);

        emit RoleAdded(caller, roleId);
    }

    /**
    * @dev Remove a roleId from the given caller address
    * This will revert if the address doesn't has the role
    * @param caller The address to remove the roleId from
    * @param roleId The roleId to remove from the given caller
    */
    function _removeRole(address caller, bytes32 roleId) internal {
        Roles.role(roleId).remove(caller);

        emit RoleRemoved(caller, roleId);
    }
}