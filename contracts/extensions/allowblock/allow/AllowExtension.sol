pragma solidity ^0.8.0;

import {IAllowlistedRole} from "./IAllowlistedRole.sol";
import {IAllowlistedAdminRole} from "./IAllowlistedAdminRole.sol";
import {TokenExtension, TransferData} from "../../TokenExtension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract AllowExtension is TokenExtension, IAllowlistedRole, IAllowlistedAdminRole {

    bytes32 constant ALLOWLIST_ROLE = keccak256("allowblock.roles.allowlisted");
    bytes32 constant ALLOWLIST_ADMIN_ROLE = keccak256("allowblock.roles.allowlisted.admin");

    constructor() {
        //Register all external functions
        _registerFunction(AllowExtension.addAllowlisted.selector);
        _registerFunction(AllowExtension.removeAllowlisited.selector);
        _registerFunction(AllowExtension.addAllowlistedAdmin.selector);
        _registerFunction(AllowExtension.removeAllowlisitedAdmin.selector);

        //Register all view functions
        _registerFunctionName('isAllowlisted(address)');
        _registerFunctionName('isAllowlistedAdmin(address)');

        //Register interfaces
        _supportInterface(type(IAllowlistedRole).interfaceId);
        _supportInterface(type(IAllowlistedAdminRole).interfaceId);

        //Register token standards supported
        _supportsAllTokenStandards();
    }

    function initalize() external override {
        _addRole(_msgSender(), ALLOWLIST_ADMIN_ROLE);
    }

    function isAllowlisted(address account) external override view returns (bool) {
        return hasRole(account, ALLOWLIST_ROLE);
    }
    
    function addAllowlisted(address account) external override onlyAllowlistedAdmin {
        _addRole(account, ALLOWLIST_ROLE);
    }

    function removeAllowlisited(address account) external override onlyAllowlistedAdmin {
        _removeRole(account, ALLOWLIST_ROLE);
    }

    function isAllowlistedAdmin(address account) external override view returns (bool) {
        return hasRole(account, ALLOWLIST_ADMIN_ROLE);
    }
    
    function addAllowlistedAdmin(address account) external override onlyAllowlistedAdmin {
        _addRole(account, ALLOWLIST_ADMIN_ROLE);
    }

    function removeAllowlisitedAdmin(address account) external override onlyAllowlistedAdmin {
        _removeRole(account, ALLOWLIST_ADMIN_ROLE);
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        if (data.from != address(0)) {
            require(hasRole(data.from, ALLOWLIST_ROLE), "from address is not allowlisted");
        }

        if (data.to != address(0)) {
            require(hasRole(data.to, ALLOWLIST_ROLE), "to address is not allowlisted");
        }

        return true;
    }
}