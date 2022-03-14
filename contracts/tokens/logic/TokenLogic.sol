pragma solidity ^0.8.0;

import {ITokenLogic} from "../../interface/ITokenLogic.sol";
import {TokenRoles} from "../../roles/TokenRoles.sol";
import {ExtendableHooks} from "../extension/ExtendableHooks.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../erc1820/ERC1820Implementer.sol";
import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";

abstract contract TokenLogic is TokenERC1820Provider, TokenRoles, ExtendableHooks, ITokenLogic {
    constructor() {
        ERC1820Client.setInterfaceImplementation(__tokenLogicInterfaceName(), address(this));
        ERC1820Implementer._setInterface(__tokenLogicInterfaceName()); // For migration
    }
}