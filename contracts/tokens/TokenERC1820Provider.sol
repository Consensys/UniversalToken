pragma solidity ^0.8.0;

import {ERC1820Client} from "../utils/erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../utils/erc1820/ERC1820Implementer.sol";

/**
* @title ERC1820 Provider for Tokens
* @notice This is an abstract contract, you may want to inherit from
* the contracts in the registry folder
* @dev A base contract that provides ERC1820 functionality and also
* provides pure functions to obtain the interface name for both the
* current token logic contract and the current token contract
*/
abstract contract TokenERC1820Provider is ERC1820Implementer, ERC1820Client {
    /**
    * @dev The interface name for the token logic contract to be used in ERC1820.
    */
    function __tokenLogicInterfaceName() internal virtual pure returns (string memory);

    /**
    * @dev The interface name for the token contract to be used in ERC1820
    */
    function __tokenInterfaceName() internal virtual pure returns (string memory);
}