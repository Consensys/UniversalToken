/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

/**
 * @title Roles
 * @dev Library for managing storage data for addresses assigned to a Role
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    function role(bytes32 _rolePosition) internal pure returns (Role storage ds) {
        bytes32 position = keccak256(abi.encodePacked("roles.storage.", _rolePosition));
        assembly {
            ds.slot := position
        }
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage r, address account) internal {
        require(!has(r, account), "Roles: account already has role");
        r.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage r, address account) internal {
        require(has(r, account), "Roles: account does not have role");
        r.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage r, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return r.bearer[account];
    }
}