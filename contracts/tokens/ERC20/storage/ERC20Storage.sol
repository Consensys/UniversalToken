pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20Storage} from "./IERC20Storage.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {ERC20ExtendableRouter} from "../extensions/ERC20ExtendableRouter.sol";
import {ERC20ExtendableLib} from "../extensions/ERC20ExtendableLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Storage is IERC20Storage, ProxyContext, ERC1820Client, ERC1820Implementer, ERC20ExtendableRouter {
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";
    string constant internal ERC20_STORAGE_INTERFACE_NAME = "ERC20TokenStorage";
    
    constructor(address token) {
        _setCallSite(token);
        
        ERC1820Client.setInterfaceImplementation(ERC20_STORAGE_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_STORAGE_INTERFACE_NAME); // For migration
    }

    modifier onlyToken {
        require(msg.sender == _callsiteAddress(), "Unauthorized");
        _;
    }

    function _getCurrentImplementationAddress() internal view returns (address) {
        address token = _callsiteAddress();
        return ERC1820Client.interfaceAddr(token, ERC20_LOGIC_INTERFACE_NAME);
    }

    function _msgSender() internal view override(Context, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external override payable onlyToken {
        bool isExt = _isExtCall();

        address toInvoke = address(0);
        if (isExt) {
            _invokeExtensionFunction();
        }
        else {
            toInvoke = _getCurrentImplementationAddress();
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

    function allExtensions() external override view onlyToken returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ERC20ExtendableLib library offers functions to do this
        return ERC20ExtendableLib._allExtensions();
    }
}