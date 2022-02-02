pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {ERC721ExtendableRouter} from "../extensions/ERC721ExtendableRouter.sol";
import {TokenStorage} from "../../storage/TokenStorage.sol";

contract ERC721Storage is TokenStorage, ERC721ExtendableRouter {
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

    function _msgSender() internal view override(Context, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    function _isExtensionFunction(bytes4 funcSig) internal override(TokenStorage, ERC721ExtendableRouter) view returns (bool) {
        ERC721ExtendableRouter._isExtensionFunction(funcSig);
    }

    function _invokeExtensionFunction() internal override(TokenStorage, ERC721ExtendableRouter) {
        ERC721ExtendableRouter._invokeExtensionFunction();
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external override(TokenStorage, ERC721ExtendableRouter) payable onlyToken {
        _fallback();
    }

    function registerExtension(address extension) external override onlyToken returns (bool) {
        return _registerExtension(extension);
    }

    function removeExtension(address extension) external override onlyToken returns (bool) {
        return _removeExtension(extension);
    }

    function disableExtension(address extension) external override onlyToken returns (bool) {
        return _disableExtension(extension);
    }

    function enableExtension(address extension) external override onlyToken returns (bool) {
        return _enableExtension(extension);
    }
}