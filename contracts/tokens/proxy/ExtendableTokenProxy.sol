pragma solidity ^0.8.0;

import {TokenProxy} from "./TokenProxy.sol";
import {IExtendableTokenProxy} from "../../interface/IExtendableTokenProxy.sol";
import {ExtendableRouter} from "../extension/ExtendableRouter.sol";
import {IExtendableTokenProxy} from "../../interface/IExtendableTokenProxy.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ExtensionLib} from "../extension/ExtensionLib.sol";
import {ExtensionStorage} from "../../extensions/ExtensionStorage.sol";
import {ITokenProxy} from "../../interface/ITokenProxy.sol";

/**
* @title Extendable Token Proxy base Contract
* @notice This should be inherited by the token proxy that wishes to use extensions
* @dev An extendable proxy contract to be used by any token standard. The final token proxy
* contract should also inherit from a TokenERC1820Provider contract or implement those functions.
* This contract does everything the TokenProxy does and adds extensions support to the proxy contract.
* This is done by extending from ExtendableRouter and providing external functions that can be used
* by the token proxy manager to manage extensions.
*
* This contract overrides the fallback function to forward any registered function selectors
* to the extension that registered them.
*
* The domain name must be implemented by the final token proxy.
*/
abstract contract ExtendableTokenProxy is TokenProxy, ExtendableRouter, IExtendableTokenProxy {
    string constant internal EXTENDABLE_INTERFACE_NAME = "ExtendableToken";

    /**
    * @dev Invoke TokenProxy constructor and register ourselves as an ExtendableToken
    * in the ERC1820 registry.
    * @param logicAddress The address to use for the logic contract. Must be non-zero
    * @param owner The address to use as the owner + manager.
    */
    constructor(address logicAddress, address owner) TokenProxy(logicAddress, owner) {
        ERC1820Client.setInterfaceImplementation(EXTENDABLE_INTERFACE_NAME, address(this));
    }

    /**
    * @notice Return an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled
    * @return address[] All registered and deployed extension proxy addresses
    */
    function allExtensions() external override view returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ExtensionLib library offers functions to do this
        return ExtensionLib._allExtensions();
    }

    /**
    * @notice Return the deployed extension proxy address given a global extension address.
    * This function reverts if the given global extension has not been registered using
    * registerExtension
    * @return address The deployed extension proxy address
    */
    function proxyAddressForExtension(address extension) external override view returns (address) {
        return ExtensionLib._proxyAddressForExtension(extension);
    }

    /**
    * @notice Register an extension providing the given global extension address. This will
    * deploy a new ExtensionStorage contract to act as the extension proxy and register
    * all function selectors the extension exposes.
    * This will also invoke the initialize function on the extension proxy. 
    *
    * Registering an extension automatically enables it for use.
    *
    * Registering an extension automatically grants any roles the extension requires to
    * the address of the deployed extension proxy.
    * See: IExtensionMetadata.requiredRoles()
    *
    * @param extension The global extension address to register
    * @return bool Whether reigstration was successful
    */
    function registerExtension(address extension) external override onlyManager returns (bool) {
        bool result = _registerExtension(extension);

        if (result) {
            address proxyAddress = ExtensionLib._proxyAddressForExtension(extension);
            ExtensionStorage proxy = ExtensionStorage(payable(proxyAddress));

            bytes32[] memory requiredRoles = proxy.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _addRole(proxyAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    /**
    * @notice Remove the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Removing an extension deletes all data about the deployed extension proxy address
    * and makes the extension's storage inaccessable forever. 
    * 
    * @param extension Either the global extension address or the deployed extension proxy address to remove
    */
    function removeExtension(address extension) external override onlyManager returns (bool) {
        bool result = _removeExtension(extension);

        if (result) {
            address proxyAddress;
            if (ExtensionLib._isProxyAddress(extension)) {
                proxyAddress = extension;
            } else {
                proxyAddress = ExtensionLib._proxyAddressForExtension(extension);
            }

            ExtensionStorage proxy = ExtensionStorage(payable(proxyAddress));

            bytes32[] memory requiredRoles = proxy.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _removeRole(proxyAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    /**
    * @notice Disable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Disabling the extension keeps the extension + storage live but simply disables
    * all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to disable
    */
    function disableExtension(address extension) external override onlyManager returns (bool) {
        return _disableExtension(extension);
    }

    /**
    * @notice Enable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to enable
    */
    function enableExtension(address extension) external override onlyManager returns (bool) {
        return _enableExtension(extension);
    }

    /**
    * @dev The default fallback function used in TokenProxy. Overriden here to add support
    * for registered extension functions. Registered extension functions are only invoked
    * if they are registered and enabled. Otherwise, the TokenProxy's fallback function is used
    * @inheritdoc TokenProxy
    */
    function _fallback() internal override virtual {
        bool isExt = _isExtensionFunction(msg.sig);

        if (isExt) {
            _invokeExtensionFunction();
        } else {
            super._fallback();
        }
    }
}