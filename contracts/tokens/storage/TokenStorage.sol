pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IExtensionStorage} from "../extension/IExtensionStorage.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ProxyContext} from "../../proxy/context/ProxyContext.sol";
import {ERC1820Implementer} from "../../erc1820/ERC1820Implementer.sol";
import {ExtensionLib} from "../extension/ExtensionLib.sol";
import {ITokenLogic} from "../ITokenLogic.sol";

abstract contract TokenStorage is IExtensionStorage, ProxyContext, ERC1820Client, ERC1820Implementer {

    constructor(address token) {
        _setCallSite(token);
    }

    modifier onlyToken {
        require(msg.sender == _callsiteAddress(), "Unauthorized");
        _;
    }

    function onUpgrade(bytes memory data) external override onlyToken returns (bool) {
        address toInvoke = _getCurrentImplementationAddress();

        //invoke the initialize function whenever we upgrade
        (bool success, bytes memory data) = toInvoke.delegatecall(
            abi.encodeWithSelector(ITokenLogic.initialize.selector, data)
        );

        return success;
    }

    function _getCurrentImplementationAddress() internal virtual view returns (address);

    function _isExtensionFunction(bytes4 funcSig) internal virtual view returns (bool);

    function _invokeExtensionFunction() internal virtual;

    function _fallback() internal {
        bool isExt = _isExtensionFunction(msg.sig);

        if (isExt) {
            _invokeExtensionFunction();
        }
        else {
            address toInvoke = _getCurrentImplementationAddress();
            // Execute external function from facet using delegatecall and return any value.
            assembly {
                // copy function selector and any arguments
                calldatacopy(0, 0, calldatasize())
                // execute function call using the facet
                let result := delegatecall(gas(), toInvoke, 0, calldatasize(), 0, 0)
                // get any return value
                returndatacopy(0, 0, returndatasize())
                // return any return value or error back to the caller
                switch result
                    case 0 {
                        revert(0, returndatasize())
                    }
                    default {
                        return(0, returndatasize())
                    }
            }
        }
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable virtual onlyToken {
        _fallback();
    }

    function allExtensions() external override view onlyToken returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ExtensionLib library offers functions to do this
        return ExtensionLib._allExtensions();
    }

    function contextAddressForExtension(address extension) external override view onlyToken returns (address) {
        return ExtensionLib._contextAddressForExtension(extension);
    }
}