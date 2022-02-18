pragma solidity ^0.8.0;

import {TokenExtension, TransferData} from "../../TokenExtension.sol";
import {IAllowlistedRole} from "./IAllowlistedRole.sol";
import {IAllowlistedAdminRole} from "./IAllowlistedAdminRole.sol";
import {TokenExtension, TransferData} from "../../TokenExtension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract AllowExtension is TokenExtension, IAllowlistedRole, IAllowlistedAdminRole {

    bytes32 constant ALLOWLIST_ROLE = keccak256("allowblock.roles.allowlisted");
    bytes32 constant ALLOWLIST_ADMIN_ROLE = keccak256("allowblock.roles.allowlisted.admin");

    modifier onlyAllowlistedAdmin {
        require(hasRole(_msgSender(), ALLOWLIST_ADMIN_ROLE), "Not an allow list admin");
        _;
    }

    modifier onlyAllowlisted {
        require(hasRole(_msgSender(), ALLOWLIST_ROLE), "Not on allow list");
        _;
    }

    modifier onlyNotAllowlisted {
        require(!hasRole(_msgSender(), ALLOWLIST_ROLE), "Already on allow list");
        _;
    }

    constructor() {
        //Register all external functions
        _registerFunctionName('isAllowlisted(address)');
        _registerFunction(AllowExtension.addAllowlisted.selector);
        _registerFunction(AllowExtension.removeAllowlisted.selector);
        _registerFunction(AllowExtension.addAllowlistedAdmin.selector);
        _registerFunction(AllowExtension.removeAllowlistedAdmin.selector);

        //Register all view functions
        _registerFunctionName('isAllowlisted(address)');
        _registerFunctionName('isAllowlistedAdmin(address)');

        //Register interfaces
        _supportInterface(type(IAllowlistedRole).interfaceId);
        _supportInterface(type(IAllowlistedAdminRole).interfaceId);

        //Register token standards supported
        _supportsAllTokenStandards();
    }

    function initialize() external override {
        _addRole(_msgSender(), ALLOWLIST_ADMIN_ROLE);
    }

    function isAllowlisted(address account) external override view returns (bool) {
        return hasRole(account, ALLOWLIST_ROLE);
    }
    
    function addAllowlisted(address account) external override onlyAllowlistedAdmin {
        _addRole(account, ALLOWLIST_ROLE);
    }

    function removeAllowlisted(address account) external override onlyAllowlistedAdmin {
        _removeRole(account, ALLOWLIST_ROLE);
    }

    function isAllowlistedAdmin(address account) external override view returns (bool) {
        return hasRole(account, ALLOWLIST_ADMIN_ROLE);
    }
    
    function addAllowlistedAdmin(address account) external override onlyAllowlistedAdmin {
        _addRole(account, ALLOWLIST_ADMIN_ROLE);
    }

    function removeAllowlistedAdmin(address account) external override onlyAllowlistedAdmin {
        _removeRole(account, ALLOWLIST_ADMIN_ROLE);
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        bool fromAllowed = hasRole(data.from, ALLOWLIST_ROLE);
        bool toAllowed = hasRole(data.to, ALLOWLIST_ROLE);
        if (data.from != address(0)) {
            require(fromAllowed, "from address is not allowlisted");
        }

        if (data.to != address(0)) {
            require(toAllowed, "to address is not allowlisted");
        }

        return fromAllowed && toAllowed;
    }
}