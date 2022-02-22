pragma solidity ^0.8.0;

import {ERC1820Client} from "../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../erc1820/ERC1820Implementer.sol";

abstract contract DynamicTokenInterface is ERC1820Implementer, ERC1820Client {
    function __tokenStorageInterfaceName() internal virtual pure returns (string memory);
    function __tokenLogicInterfaceName() internal virtual pure returns (string memory);
    function __tokenInterfaceName() internal virtual pure returns (string memory);
}