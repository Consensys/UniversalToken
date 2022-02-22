pragma solidity ^0.8.0;

import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../erc1820/ERC1820Implementer.sol";
import {TokenRoles} from "../roles/TokenRoles.sol";
import {DomainAware} from "../../tools/DomainAware.sol";
import {ITokenStorage, IExtensionStorage} from "../ITokenStorage.sol";
import {ExtensionStorage} from "../../extensions/ExtensionStorage.sol";
import {ITokenProxy} from "../ITokenProxy.sol";

abstract contract TokenProxy is TokenRoles, DomainAware, ERC1820Client, ERC1820Implementer, ITokenProxy {
    function __tokenStorageInterfaceName() internal virtual pure returns (string memory);
    function __tokenLogicInterfaceName() internal virtual pure returns (string memory);

    function _getTokenStorage() internal view returns (ITokenStorage) {
        return ITokenStorage(_getStorageContractAddress());
    }

    function _getStorageContractAddress() internal view returns (address) {
        return ERC1820Client.interfaceAddr(address(this), __tokenStorageInterfaceName());
    }

    function _getImplementationContractAddress() internal view returns (address) {
        return ERC1820Client.interfaceAddr(address(this), __tokenLogicInterfaceName());
    }

    function _setImplementation(address implementation) internal {
        ERC1820Client.setInterfaceImplementation(__tokenLogicInterfaceName(), implementation);
    }

    function _setStorage(address store) internal {
        ERC1820Client.setInterfaceImplementation(__tokenStorageInterfaceName(), store);
    }

    function upgradeTo(address implementation, bytes memory data) external override onlyManager {
        _setImplementation(implementation);

        //Invoke initialize
        require(_getTokenStorage().onUpgrade(data), "Logic initializing failed");
    }

    function registerExtension(address extension) external override onlyManager returns (bool) {
        // Lets cann regiterExtension, but ensure we pass along _msgSender
        // We do this by encoding the call and using _forwardCall
        // Forward call to storage contract, appending the current _msgSender to the
        // end of the current calldata
        bytes memory cdata = abi.encodeWithSelector(IExtensionStorage.registerExtension.selector, extension);
        (bool result, ) = _forwardCall(cdata);

        if (result) {
            address contextAddress = _getTokenStorage().contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _addRole(ctxAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function removeExtension(address extension) external override onlyManager returns (bool) {
       bool result = _getTokenStorage().removeExtension(extension);

       if (result) {
            address contextAddress = _getTokenStorage().contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _removeRole(ctxAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function disableExtension(address extension) external override onlyManager returns (bool) {
        return _getTokenStorage().disableExtension(extension);
    }

    function enableExtension(address extension) external override onlyManager returns (bool) {
        return _getTokenStorage().enableExtension(extension);
    }

    function allExtensions() external override view returns (address[] memory) {
        return _getTokenStorage().allExtensions();
    }

    function contextAddressForExtension(address extension) external override view returns (address) {
        return _getTokenStorage().contextAddressForExtension(extension);
    }

    // Forward any function not found here to the storage
    // contract, appending _msgSender() to the end of the 
    // calldata provided and return any values
    fallback() external override payable {
        //we cant define a return value for fallback in solidity
        //therefore, we must do the call in in-line assembly
        //so we can use the return() opcode to return
        //dynamic data from the storage contract

        //This is because the storage contract may return
        //anything, since both the logic contract or
        //the registered & enabled extensions can return
        //something
        address store = _getStorageContractAddress();
        bytes memory cdata = abi.encodePacked(_msgData(), _msgSender());
        uint256 value = msg.value;

        // Forward the external call using call and return any value
        // and reverting if the call failed
        assembly {
            // execute function call
            let result := call(gas(), store, value, add(cdata, 0x20), mload(cdata), 0, 0)
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

    function _forwardCurrentCall() internal returns (bool, bytes memory) {
        return _forwardCall(_msgData());
    }

    function _forwardCall(bytes memory _calldata) internal returns (bool success, bytes memory result) {
        address store = _getStorageContractAddress();

        // Forward call to storage contract, appending the current _msgSender to the
        // end of the current calldata
        bytes memory newData = abi.encodePacked(_calldata, _msgSender());

        // Forward the external call using call and return any value
        // and reverting if the call failed
        (success, result) = store.call{gas: gasleft(), value: msg.value}(newData);

        if (!success) {
            revert(string(result));
        }
    }
    
    receive() external override payable {}

    function _domainVersion() internal virtual override view returns (bytes32) {
        return bytes32(uint256(uint160(_getImplementationContractAddress())));
    }
}