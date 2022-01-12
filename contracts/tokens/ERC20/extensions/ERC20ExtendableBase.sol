pragma solidity ^0.8.0;

import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";

abstract contract ERC20ExtendableBase is ERC1820Client {
    string constant internal ERC20_EXTENDABLE_INTERFACE_NAME = "ERC20Extendable";

    constructor() {
        ERC1820Client.setInterfaceImplementation(ERC20_EXTENDABLE_INTERFACE_NAME, address(this));
    }
}