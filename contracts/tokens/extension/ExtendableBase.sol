pragma solidity ^0.8.0;

import {ProxyContext} from "../../proxy/context/ProxyContext.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";

abstract contract ExtendableBase is ProxyContext, ERC1820Client {
    string constant internal EXTENDABLE_INTERFACE_NAME = "ExtendableToken";

    constructor() {
        ERC1820Client.setInterfaceImplementation(EXTENDABLE_INTERFACE_NAME, address(this));
    }
}