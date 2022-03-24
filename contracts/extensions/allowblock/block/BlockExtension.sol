pragma solidity ^0.8.0;

import {IBlocklistedRole} from "./IBlocklistedRole.sol";
import {IBlocklistedAdminRole} from "./IBlocklistedAdminRole.sol";
import {TokenExtension, TransferData} from "../../TokenExtension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract BlockExtension is TokenExtension, IBlocklistedRole, IBlocklistedAdminRole {

    bytes32 constant BLOCKLIST_ROLE = keccak256("allowblock.roles.blocklisted");
    bytes32 constant BLOCKLIST_ADMIN_ROLE = keccak256("allowblock.roles.blocklisted.admin");

    modifier onlyBlocklistedAdmin {
        require(this.isBlocklistedAdmin(_msgSender()), "Not on block list admin");
        _;
    }

    
    modifier onlyNotBlocklisted {
        require(!this.isBlocklisted(_msgSender()), "Already on block list");
        _;
    }

    modifier onlyBlocklisted {
        require(this.isBlocklisted(_msgSender()), "Not on block list");
        _;
    }

    constructor() {
        _registerFunction(BlockExtension.addBlocklisted.selector);
        _registerFunction(BlockExtension.removeBlocklisted.selector);
        _registerFunction(BlockExtension.addBlocklistedAdmin.selector);
        _registerFunction(BlockExtension.removeBlocklistedAdmin.selector);

        _registerFunctionName('isBlocklisted(address)');
        _registerFunctionName('isBlocklistedAdmin(address)');

        _supportInterface(type(IBlocklistedRole).interfaceId);
        _supportInterface(type(IBlocklistedAdminRole).interfaceId);

        _supportsAllTokenStandards();

        _setPackageName("net.consensys.tokenext.BlockExtension");
        _setVersion(1);
    }

    function initialize() external override {
        _addRole(_msgSender(), BLOCKLIST_ADMIN_ROLE);
    }

    function isBlocklisted(address account) external override view returns (bool) {
        return hasRole(account, BLOCKLIST_ROLE);
    }

    function addBlocklisted(address account) external override onlyBlocklistedAdmin {
        _addRole(account, BLOCKLIST_ROLE);
    }

    function removeBlocklisted(address account) external override onlyBlocklistedAdmin {
        _removeRole(account, BLOCKLIST_ROLE);
    }

    function isBlocklistedAdmin(address account) external override view returns (bool) {
        return hasRole(account, BLOCKLIST_ADMIN_ROLE);
    }

    function addBlocklistedAdmin(address account) external override onlyBlocklistedAdmin {
        _addRole(account, BLOCKLIST_ADMIN_ROLE);
    }

    function removeBlocklistedAdmin(address account) external override onlyBlocklistedAdmin {
        _removeRole(account, BLOCKLIST_ADMIN_ROLE);
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        if (data.from != address(0)) {
            require(!hasRole(data.from, BLOCKLIST_ROLE), "from address is blocklisted");
        }

        if (data.to != address(0)) {
            require(!hasRole(data.to, BLOCKLIST_ROLE), "to address is blocklisted");
        }
        
        return true;
    }
}