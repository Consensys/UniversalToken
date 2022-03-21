pragma solidity ^0.8.0;

import {ITokenLogic} from "../../interface/ITokenLogic.sol";
import {TokenRoles} from "../../roles/TokenRoles.sol";
import {ExtendableHooks} from "../extension/ExtendableHooks.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../erc1820/ERC1820Implementer.sol";
import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";

/**
* @title Base Token Logic Contract
* @author Edward Penta
* @notice This should be inherited by the token logic contract
* @dev An abstract contract to be inherited by a token logic contract. This contract
* inherits from TokenERC1820Provider, TokenRoles and ExtendableHooks. It is recommended
* that a token logic contract inherit from a TokenERC1820Provider contract or implement those functions.
*
* This contract uses the TokenERC1820Provider to automatically register the required token logic
* interface name to the ERC1820 registry. This is used by the token proxy contract to lookup the current
* token logic address.
*/
abstract contract TokenLogic is TokenERC1820Provider, TokenRoles, ExtendableHooks, ITokenLogic {
    constructor() {
        ERC1820Client.setInterfaceImplementation(__tokenLogicInterfaceName(), address(this));
        ERC1820Implementer._setInterface(__tokenLogicInterfaceName()); // For migration
    }
}