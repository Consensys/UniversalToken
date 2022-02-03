pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {TokenStorage} from "../../storage/TokenStorage.sol";

contract ERC20Storage is TokenStorage {
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";
    string constant internal ERC20_STORAGE_INTERFACE_NAME = "ERC20TokenStorage";
    
    constructor(address token) TokenStorage(token) {
        ERC1820Client.setInterfaceImplementation(ERC20_STORAGE_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_STORAGE_INTERFACE_NAME); // For migration
    }
    
    function _getCurrentImplementationAddress() internal override view returns (address) {
        address token = _callsiteAddress();
        return ERC1820Client.interfaceAddr(token, ERC20_LOGIC_INTERFACE_NAME);
    }
}