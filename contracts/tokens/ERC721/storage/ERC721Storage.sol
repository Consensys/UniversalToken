pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {TokenStorage} from "../../storage/TokenStorage.sol";

contract ERC721Storage is TokenStorage {
    string constant internal ERC721_LOGIC_INTERFACE_NAME = "ERC721TokenLogic";
    string constant internal ERC721_STORAGE_INTERFACE_NAME = "ERC721TokenStorage";
    
    constructor(address token) TokenStorage(token) {
        ERC1820Client.setInterfaceImplementation(ERC721_STORAGE_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC721_STORAGE_INTERFACE_NAME); // For migration
    }

    function _getCurrentImplementationAddress() internal override view returns (address) {
        address token = _callsiteAddress();
        return ERC1820Client.interfaceAddr(token, ERC721_LOGIC_INTERFACE_NAME);
    }
}