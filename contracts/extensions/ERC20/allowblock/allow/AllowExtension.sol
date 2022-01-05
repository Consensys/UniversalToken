pragma solidity ^0.8.0;

import {IAllowlistedRole} from "./IAllowlistedRole.sol";
import {IAllowlistedAdminRole} from "./IAllowlistedAdminRole.sol";
import {AllowBlockLib} from "../AllowBlockLib.sol";
import {ERC20Extension} from "../../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract AllowExtension is ERC20Extension, IAllowlistedRole, IAllowlistedAdminRole {

    constructor() {
        _registerFunction(AllowExtension.addAllowlisted.selector);
        _registerFunction(AllowExtension.removeAllowlisited.selector);
        _registerFunction(AllowExtension.addAllowlistedAdmin.selector);
        _registerFunction(AllowExtension.removeAllowlisitedAdmin.selector);

        _registerFunctionName('isAllowlisted(address)');
        _registerFunctionName('isAllowlistedAdmin(address)');

        _supportInterface(type(IAllowlistedRole).interfaceId);
        _supportInterface(type(IAllowlistedAdminRole).interfaceId);
    }

    function initalize() external override {
        AllowBlockLib.addAllowlistedAdmin(msg.sender);
    }

    function isAllowlisted(address account) external override view returns (bool) {
        return AllowBlockLib.isAllowlisted(account);
    }
    
    function addAllowlisted(address account) external override onlyAllowlistedAdmin {
        AllowBlockLib.addAllowlisted(account);
    }

    function removeAllowlisited(address account) external override onlyAllowlistedAdmin {
        AllowBlockLib.removeAllowlisited(account);
    }

    function isAllowlistedAdmin(address account) external override view returns (bool) {
        return AllowBlockLib.isAllowlistedAdmin(account);
    }
    
    function addAllowlistedAdmin(address account) external override onlyAllowlistedAdmin {
        AllowBlockLib.addAllowlistedAdmin(account);
    }

    function removeAllowlisitedAdmin(address account) external override onlyAllowlistedAdmin {
        AllowBlockLib.removeAllowlisitedAdmin(account);
    }

    function validateTransfer(TransferData memory data) external override view returns (bool) {
        if (data.from != address(0)) {
            require(AllowBlockLib.isAllowlisted(data.from), "from address is not allowlisted");
        }

        if (data.to != address(0)) {
            require(AllowBlockLib.isAllowlisted(data.to), "to address is not allowlisted");
        }

        return true;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        if (data.from != address(0)) {
            require(AllowBlockLib.isAllowlisted(data.from), "from address is not allowlisted");
        }

        if (data.to != address(0)) {
            require(AllowBlockLib.isAllowlisted(data.to), "to address is not allowlisted");
        }

        return true;
    }
}