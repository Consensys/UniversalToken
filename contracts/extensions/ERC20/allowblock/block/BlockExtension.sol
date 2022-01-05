pragma solidity ^0.8.0;

import {IBlocklistedRole} from "./IBlocklistedRole.sol";
import {IBlocklistedAdminRole} from "./IBlocklistedAdminRole.sol";
import {AllowBlockLib} from "../AllowBlockLib.sol";
import {ERC20Extension} from "../../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract BlockExtension is ERC20Extension, IBlocklistedRole, IBlocklistedAdminRole {

    constructor() {
        _registerFunction(BlockExtension.addBlocklisted.selector);
        _registerFunction(BlockExtension.removeBlocklisted.selector);
        _registerFunction(BlockExtension.addBlocklistedAdmin.selector);
        _registerFunction(BlockExtension.removeBlocklistedAdmin.selector);

        _registerFunctionName('isBlocklisted(address)');
        _registerFunctionName('isBlocklistedAdmin(address)');

        _supportInterface(type(IBlocklistedRole).interfaceId);
        _supportInterface(type(IBlocklistedAdminRole).interfaceId);
    }

    function initalize() external override {
        AllowBlockLib.addBlocklistedAdmin(msg.sender);
    }

    function isBlocklisted(address account) external override view returns (bool) {
        return AllowBlockLib.isBlocklisted(account);
    }

    function addBlocklisted(address account) external override onlyBlocklistedAdmin {
        AllowBlockLib.addBlocklisted(account);
    }

    function removeBlocklisted(address account) external override onlyBlocklistedAdmin {
        AllowBlockLib.removeBlocklisted(account);
    }

    function isBlocklistedAdmin(address account) external override view returns (bool) {
        return AllowBlockLib.isBlocklistedAdmin(account);
    }

    function addBlocklistedAdmin(address account) external override onlyBlocklistedAdmin {
        AllowBlockLib.addBlocklistedAdmin(account);
    }

    function removeBlocklistedAdmin(address account) external override onlyBlocklistedAdmin {
        AllowBlockLib.removeBlocklistedAdmin(account);
    }

    function validateTransfer(TransferData memory data) external override view returns (bool) {
        if (data.from != address(0)) {
            require(!AllowBlockLib.isBlocklisted(data.from), "from address is blocklisted");
        }

        if (data.to != address(0)) {
            require(!AllowBlockLib.isBlocklisted(data.to), "to address is blocklisted");
        }

        return true;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        if (data.from != address(0)) {
            require(!AllowBlockLib.isBlocklisted(data.from), "from address is blocklisted");
        }

        if (data.to != address(0)) {
            require(!AllowBlockLib.isBlocklisted(data.to), "to address is blocklisted");
        }
        
        return true;
    }
}