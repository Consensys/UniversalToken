pragma solidity ^0.8.0;

import {IToken, TokenStandard} from "../../../interface/IToken.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ExtendableHooks} from "../../extension/ExtendableHooks.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {TransferData} from "../../../extensions/IExtension.sol";
import {TokenRoles} from "../../../roles/TokenRoles.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {ITokenLogic} from "../../../interface/ITokenLogic.sol";

contract ERC1155Logic is ERC1155Upgradeable, ERC1820Client, ERC1820Implementer, ExtendableHooks, ITokenLogic {
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";

    bytes private _currentData;
    bytes private _currentOperatorData;

    constructor() {
        ERC1820Client.setInterfaceImplementation(ERC20_LOGIC_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_LOGIC_INTERFACE_NAME); // For migration
    }

    function initialize(bytes memory data) external override {
        require(msg.sender == _callsiteAddress(), "Unauthorized");
        require(_onInitialize(data), "Initialize failed");
    }

    function _onInitialize(bytes memory data) internal virtual returns (bool) {
        return true;
    }

    function _msgSender() internal view override(ContextUpgradeable, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, Context) returns (bytes memory) {
        return ContextUpgradeable._msgData();
    }

    function tokenTransfer(TransferData calldata td) external override returns (bool) {
        //TODO

        return true;
    }

    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC1155;
    }
}