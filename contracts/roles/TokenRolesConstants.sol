pragma solidity ^0.8.0;

abstract contract TokenRolesConstants {
        /**
    * @dev The storage slot for the burn/burnFrom toggle
    */
    bytes32 constant TOKEN_ALLOW_BURN = keccak256("token.proxy.core.burn");
    /**
    * @dev The storage slot for the mint toggle
    */
    bytes32 constant TOKEN_ALLOW_MINT = keccak256("token.proxy.core.mint");
    /**
    * @dev The storage slot that holds the current Owner address
    */
    bytes32 constant TOKEN_OWNER = keccak256("token.proxy.core.owner");
    /**
    * @dev The access control role ID for the Minter role
    */
    bytes32 constant TOKEN_MINTER_ROLE = keccak256("token.proxy.core.mint.role");
    /**
    * @dev The storage slot that holds the current Manager address
    */
    bytes32 constant TOKEN_MANAGER_ADDRESS = bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1);
    /**
    * @dev The access control role ID for the Controller role
    */
    bytes32 constant TOKEN_CONTROLLER_ROLE = keccak256("token.proxy.controller.address");
}