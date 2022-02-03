pragma solidity ^0.8.0;

import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";

abstract contract ExtendableBase is ERC1820Client {
    string constant internal EXTENDABLE_INTERFACE_NAME = "ExtendableToken";

    constructor() {
        ERC1820Client.setInterfaceImplementation(EXTENDABLE_INTERFACE_NAME, address(this));
    }
}