pragma solidity ^0.8.0;

import {TokenProxy} from "./TokenProxy.sol";
import {IExtendableTokenProxy} from "./IExtendableTokenProxy.sol";
import {ERC1820Client} from "../../utils/erc1820/ERC1820Client.sol";
import {ExtensionProxy} from "../../extensions/ExtensionProxy.sol";
import {ITokenProxy} from "./ITokenProxy.sol";
import {IExtension, TransferData} from "../../extensions/IExtension.sol";
import {RegisteredExtensionStorage} from "../storage/RegisteredExtensionStorage.sol";

/**
* @title Extendable Token Proxy base Contract
* @notice This should be inherited by the token proxy that wishes to use extensions
* @dev An extendable proxy contract to be used by any token standard. The final token proxy
* contract should also inherit from a TokenERC1820Provider contract or implement those functions.
* This contract does everything the TokenProxy does and adds extensions support to the proxy contract.
* This is done by extending from ExtendableProxy and providing external functions that can be used
* by the token proxy manager to manage extensions.
*
* This contract overrides the fallback function to forward any registered function selectors
* to the extension that registered them.
*
* The domain name must be implemented by the final token proxy.
*/
abstract contract ExtendableTokenProxy is TokenProxy, RegisteredExtensionStorage, IExtendableTokenProxy {
    string constant internal EXTENDABLE_INTERFACE_NAME = "ExtendableToken";

    /**
    * @dev A function modifier that will only allow registered & enabled extensions to invoke the function
    */
    modifier onlyExtensions {
        address extension = _msgSender();
        require(_isActiveExtension(extension), "Only extensions can call");
        _;
    }

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
    * @notice Return an array of all global extension addresses, regardless of if they are
    * enabled or disabled. You cannot interact with these addresses. For user interaction
    * you should use ExtendableTokenProxy.allExtensionProxies
    * @return address[] All registered and deployed extension proxy addresses
    */
    function allExtensionsRegistered() external override view returns (address[] memory) {
        return _allExtensionsRegistered();
    }

    /**
    * @notice Return an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled. You can use these addresses for direct interaction. Remember you can also
    * interact with extensions through the TokenProxy.
    * @return address[] All registered and deployed extension proxy addresses
    */
    function allExtensionProxies() external override view returns (address[] memory) {
        return _allExtensionProxies();
    }

    /**
    * @notice Return the deployed extension proxy address given a global extension address.
    * This function reverts if the given global extension has not been registered using
    * registerExtension
    * @return address The deployed extension proxy address
    */
    function proxyAddressForExtension(address extension) external override view returns (address) {
        return _proxyAddressForExtension(extension);
    }

    /**
    * @notice Register an extension providing the given global extension address. This will
    * deploy a new ExtensionProxy contract to act as the extension proxy and register
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
    */
    function registerExtension(address extension) external override onlyManager {
        _registerExtension(extension, address(this), _msgSender());

        address proxyAddress = _proxyAddressForExtension(extension);
        ExtensionProxy proxy = ExtensionProxy(payable(proxyAddress));

        bytes32[] memory requiredRoles = proxy.requiredRoles();
        
        //If we have roles we need to register, then lets register them
        if (requiredRoles.length > 0) {
            for (uint i = 0; i < requiredRoles.length; i++) {
                _addRole(proxyAddress, requiredRoles[i]);
            }
        }
    }

    /**
    * @notice Upgrade a registered extension at the given global extension address. This will perform
    * an upgrade on the ExtensionProxy contract that was deployed during registration. The new global
    * extension address must have the same deployer and package hash.
    * @param extension The global extension address to upgrade
    * @param newExtension The new global extension address to upgrade the extension to
    */
    function upgradeExtension(address extension, address newExtension) external override onlyManager {
        address proxyAddress = _proxyAddressForExtension(extension);
        require(proxyAddress != address(0), "Extension is not registered");

        ExtensionProxy proxy = ExtensionProxy(payable(proxyAddress));

        proxy.upgradeTo(newExtension);
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
    function removeExtension(address extension) external override onlyManager {
        _removeExtension(extension);

        address proxyAddress;
        if (_isExtensionProxyAddress(extension)) {
            proxyAddress = extension;
        } else {
            proxyAddress = _proxyAddressForExtension(extension);
        }

        ExtensionProxy proxy = ExtensionProxy(payable(proxyAddress));

        bytes32[] memory requiredRoles = proxy.requiredRoles();
        
        //If we have roles we need to register, then lets register them
        if (requiredRoles.length > 0) {
            for (uint i = 0; i < requiredRoles.length; i++) {
                _removeRole(proxyAddress, requiredRoles[i]);
            }
        }
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
    function disableExtension(address extension) external override onlyManager {
        _disableExtension(extension);
    }

    /**
    * @notice Enable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param extension Either the global extension address or the deployed extension proxy address to enable
    */
    function enableExtension(address extension) external override onlyManager {
        _enableExtension(extension);
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

        /**
    * @dev Register an extension at the given global extension address. This will
    * deploy a new ExtensionProxy contract to act as the extension proxy and register
    * all function selectors the extension exposes.
    * This will also invoke the initialize function on the extension proxy, to do this 
    * we must know who the current caller is.
    * Registering an extension automatically enables it for use.
    *
    * @param extension The global extension address to register
    * @param token The token address that will be using this extension
    * @param caller The current caller that will be initalizing the extension proxy
    */
    function _registerExtension(address extension, address token, address caller) internal returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        require(extLibStorage.extensions[extension].state == ExtensionState.EXTENSION_NOT_EXISTS, "The extension must not already exist");

        //TODO Register with 1820
        //Interfaces has been validated, lets begin setup

        //Next we need to deploy the ExtensionProxy contract
        //To sandbox our extension's storage
        ExtensionProxy extProxy = new ExtensionProxy(token, extension, address(this));

        //Next lets figure out what external functions to register in the Extension
        bytes4[] memory externalFunctions = extProxy.externalFunctions();

        //If we have external functions to register, then lets register them
        if (externalFunctions.length > 0) {
            for (uint i = 0; i < externalFunctions.length; i++) {
                bytes4 func = externalFunctions[i];
                require(extLibStorage.funcToExtension[func] == address(0), "Function signature conflict");
                //STATICCALLMAGIC not allowed
                require(func != hex"ffffffff", "Invalid function signature");

                extLibStorage.funcToExtension[func] = extension;
            }
        }

        //Finally, add it to storage
        extLibStorage.extensions[extension] = ExtensionData(
            ExtensionState.EXTENSION_ENABLED,
            extLibStorage.registeredExtensions.length,
            address(extProxy),
            externalFunctions
        );

        extLibStorage.registeredExtensions.push(extension);
        extLibStorage.proxyCache[address(extProxy)] = extension;

        //Initialize the new extension proxy
        bytes memory initializeCalldata = abi.encodePacked(abi.encodeWithSelector(ExtensionProxy.initialize.selector), _msgSender());

        (bool success, bytes memory result) = address(extProxy).call{gas: gasleft()}(initializeCalldata);

        if (!success) {
            revert(string(result));
        }

        return true;
    }

    /**
    * @dev Get the deployed extension proxy address that registered the provided
    * function selector. If no extension registered the given function selector,
    * then return address(0). If the extension that registered the function selector is disabled,
    * then the address(0) is returned
    * @param funcSig The function signature to lookup
    * @return address Returns the deployed enabled extension proxy address that registered the
    * provided function selector, otherwise address(0)
    */
    function _functionToExtensionProxyAddress(bytes4 funcSig) internal view returns (address) {
        MappedExtensions storage extLibStorage = _extensionStorage();

        ExtensionData storage extData = extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];

        //Only return an address for an extension that is enabled
        if (extData.state == ExtensionState.EXTENSION_ENABLED) {
            return extData.extProxy;
        }

        return address(0);
    }

    /**
    * @dev Get the full ExtensionData of the extension that registered the provided
    * function selector, even if the extension is currently disabled. 
    * If no extension registered the given function selector, then a blank ExtensionData is returned.
    * @param funcSig The function signature to lookup
    * @return ExtensionData Returns the full ExtensionData of the extension that registered the
    * provided function selector
    */
    function _functionToExtensionData(bytes4 funcSig) internal view returns (ExtensionData storage) {
        MappedExtensions storage extLibStorage = _extensionStorage();

        require(extLibStorage.funcToExtension[funcSig] != address(0), "Unknown function");

        return extLibStorage.extensions[extLibStorage.funcToExtension[funcSig]];
    }

    /**
    * @dev Disable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Disabling the extension keeps the extension + storage live but simply disables
    * all registered functions and transfer events
    *
    * @param ext Either the global extension address or the deployed extension proxy address to disable
    */
    function _disableExtension(address ext) internal {
        MappedExtensions storage extLibStorage = _extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_ENABLED, "The extension must be enabled");

        extData.state = ExtensionState.EXTENSION_DISABLED;
        //extLibStorage.proxyCache[extData.extProxy] = address(0);
    }

    /**
    * @dev Enable the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Enabling the extension simply enables all registered functions and transfer events
    *
    * @param ext Either the global extension address or the deployed extension proxy address to enable
    */
    function _enableExtension(address ext) internal {
        MappedExtensions storage extLibStorage = _extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state == ExtensionState.EXTENSION_DISABLED, "The extension must be enabled");

        extData.state = ExtensionState.EXTENSION_ENABLED;
        //extLibStorage.proxyCache[extData.extProxy] = extension;
    }

    /**
    * @dev Check whether a given address is a deployed extension proxy address that
    * is registered.
    *
    * @param callsite The address to check
    */
    function _isExtensionProxyAddress(address callsite) internal view returns (bool) {
        MappedExtensions storage extLibStorage = _extensionStorage();

        return extLibStorage.proxyCache[callsite] != address(0);
    }

    /**
    * @dev Get an array of all global extension addresses that have been registered, regardless of if they are
    * enabled or disabled
    */
    function _allExtensionsRegistered() internal view returns (address[] storage) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        return extLibStorage.registeredExtensions;
    }

    /**
    * @dev Get an array of all deployed extension proxy addresses, regardless of if they are
    * enabled or disabled
    */
    function _allExtensionProxies() internal view returns (address[] memory) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        address[] storage globalAddresses = extLibStorage.registeredExtensions;
        address[] memory proxyAddresses = new address[](globalAddresses.length);

        for (uint i = 0; i < proxyAddresses.length; i++) {
            proxyAddresses[i] = _proxyAddressForExtension(globalAddresses[i]);
        }

        return proxyAddresses;
    }

    /**
    * @dev Get the deployed extension proxy address given a global extension address. 
    * This function assumes the given global extension address has been registered using
    *  _registerExtension.
    * @param extension The global extension address to convert
    */
    function _proxyAddressForExtension(address extension) internal view returns (address) {
        MappedExtensions storage extLibStorage = _extensionStorage();
        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state != ExtensionState.EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

        return extData.extProxy;
    }

    /**
    * @dev Remove the extension at the provided address. This may either be the
    * global extension address or the deployed extension proxy address. 
    *
    * Removing an extension deletes all data about the deployed extension proxy address
    * and makes the extension's storage inaccessable forever.
    *
    * @param ext Either the global extension address or the deployed extension proxy address to remove
    */
    function _removeExtension(address ext) internal {
        MappedExtensions storage extLibStorage = _extensionStorage();
        address extension = __forceGlobalExtensionAddress(ext);

        ExtensionData storage extData = extLibStorage.extensions[extension];

        require(extData.state != ExtensionState.EXTENSION_NOT_EXISTS, "The extension must exist (either enabled or disabled)");

        // To prevent a gap in the extensions array, we store the last extension in the index of the extension to delete, and
        // then delete the last slot (swap and pop).
        uint256 lastExtensionIndex = extLibStorage.registeredExtensions.length - 1;
        uint256 extensionIndex = extData.index;

        // When the extension to delete is the last extension, the swap operation is unnecessary. However, since this occurs so
        // rarely that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement
        address lastExtension = extLibStorage.registeredExtensions[lastExtensionIndex];

        extLibStorage.registeredExtensions[extensionIndex] = lastExtension;
        extLibStorage.extensions[lastExtension].index = extensionIndex;

        extLibStorage.proxyCache[extData.extProxy] = address(0);
        delete extLibStorage.extensions[extension];
        extLibStorage.registeredExtensions.pop();
    }

    /**
    * @dev Go through each extension, if it's enabled execute the implemented function and pass the extension
    * If any invokation of the implemented function given an extension returns false, halt and return false
    * If they all return true (or there are no extensions), then return true
    * @param toInvoke The function that should be invoked with each enabled extension
    * @param data The current data that will be passed to the implemented function along with the enabled extension address
    * @return bool True if all extensions were executed successfully, false if any extension returned false
    */
    function _executeOnAllExtensions(function (address, TransferData memory) internal returns (bool) toInvoke, TransferData memory data) internal returns (bool) {
        MappedExtensions storage extLibData = _extensionStorage();

        for (uint i = 0; i < extLibData.registeredExtensions.length; i++) {
            address extension = extLibData.registeredExtensions[i];

            ExtensionData memory extData = extLibData.extensions[extension]; 

            if (extData.state == ExtensionState.EXTENSION_DISABLED) {
                continue; //Skip if the extension is disabled
            }

            //Execute the implemented function using the enabled extension
            //however, execute the call at the ExtensionProxy contract address
            //The ExtensionProxy contract will delegatecall the extension logic
            //and manage storage/api
            address proxy = extData.extProxy;
            bool result = toInvoke(proxy, data);
            if (!result) {
                return false;
            }
        }

        return true;
    }

    /**
    * @dev Call a registered function selector. This will 
    * lookup the deployed extension proxy that registered the provided
    * function selector and call it. The current call data is forwarded.
    *
    * This call returns and exits the current call context.
    *
    * If the provided function selector is not registered by any enabled 
    * extensions, then the revert is thrown
    *
    * @param funcSig The registered function selector to call.
    */
    function _callFunction(bytes4 funcSig) private {
        // get extension proxy address from function selector
        address toCall = _functionToExtensionProxyAddress(funcSig);
        require(toCall != address(0), "EXTROUTER: Function does not exist");

        bytes memory finalData = abi.encodePacked(_msgData(), _msgSender());

        uint256 value = msg.value;

        // Execute external function from facet using call and return any value.
        assembly {
            // execute function call using the facet
            let result := call(gas(), toCall, value, add(finalData, 0x20), mload(finalData), 0, 0)
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

    /**
    * @dev Determine if a given function selector is registered by an enabled
    * deployed extension proxy address. If no extension proxy exists or if the 
    * deployed extension proxy address is disabled, then false is returned
    *
    * @param funcSig The function selector to check
    * @return bool True if an enabled deployed extension proxy address has registered
    * the provided function selector, otherwise false.
    */
    function _isExtensionFunction(bytes4 funcSig) internal virtual view returns (bool) {
        return _functionToExtensionProxyAddress(funcSig) != address(0);
    }

    /**
    * @dev Forward the current call to the proper deployed extension proxy address. This
    * function assumes the current function selector is registered by an enabled deployed extension proxy address.
    *
    * This call returns and exits the current call context.
    */
    function _invokeExtensionFunction() internal virtual {
        require(_isExtensionFunction(msg.sig), "No extension found with function signature");

        _callFunction(msg.sig);
    }
}