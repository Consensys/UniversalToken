pragma solidity ^0.8.0;

import {TokenProxy} from "./TokenProxy.sol";
import {IExtendableTokenProxy} from "./IExtendableTokenProxy.sol";
import {ExtendableDiamond} from "../extension/ExtendableDiamond.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../erc1820/ERC1820Implementer.sol";
import {IExtension} from "../../interface/IExtension.sol";
import {ITokenProxy} from "./ITokenProxy.sol";
import {Errors} from "../../helpers/Errors.sol";


/**
* @title Extendable Token Proxy base Contract
* @notice This should be inherited by the token proxy that wishes to use extensions
* @dev An extendable proxy contract to be used by any token standard. The final token proxy
* contract should also inherit from a TokenERC1820Provider contract or implement those functions.
* This contract does everything the TokenProxy does and adds extensions support to the proxy contract.
* This is done by extending from ExtendableDiamond and providing external functions that can be used
* by the token proxy manager to manage extensions.
*
* This contract overrides the fallback function to forward any registered function selectors
* to the extension that registered them.
*
* The domain name must be implemented by the final token proxy.
*/
abstract contract ExtendableTokenProxy is TokenProxy, ExtendableDiamond, IExtendableTokenProxy {
    string constant internal EXTENDABLE_INTERFACE_NAME = "ExtendableToken";

    /**
    * @dev A function modifier that will only allow registered & enabled extensions to invoke the function
    */
    modifier onlyExtensions {
        address extension = _msgSender();
        require(_isActiveExtension(extension), Errors.UNAUTHORIZED_ONLY_EXTENSIONS);
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
        ERC1820Implementer._setInterface(EXTENDABLE_INTERFACE_NAME); // For migration
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
    * @notice Register an extension providing the given global extension address.  This will create a new
    * DiamondCut with the extension address being the facet. All external functions the extension
    * exposes will be registered with the DiamondCut. The DiamondCut will be initalized by calling
    * the initialize function on the extension through delegatecall
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
        _registerExtension(extension);

        IExtension ext = IExtension(extension);

        string memory interfaceLabel = ext.interfaceLabel();

        ERC1820Client.setInterfaceImplementation(interfaceLabel, address(this));
        ERC1820Implementer._setInterface(interfaceLabel); // For migration

        _addRequiredRolesForExtension(extension);
    }

    function _addRequiredRolesForExtension(address extension) internal {
        //The registered extension in a diamond is delegatecalled
        //That means any token actions the extension may request via
        //a normal call will come from ourselves (address(this))
        //so grant any required roles to ourselves if we dont
        //already have it
        address user = address(this);

        bytes32[] memory requiredRoles = IExtension(extension).requiredRoles();

        //If we have roles we need to register, then lets register them
        if (requiredRoles.length > 0) {
            for (uint i = 0; i < requiredRoles.length; i++) {
                if (!hasRole(user, requiredRoles[i])) {
                    _addRole(user, requiredRoles[i]);
                }
            }
        }
    }

    /**
    * @notice Upgrade a registered extension at the given global extension address. This will
    * perform a replacement DiamondCut. The new global extension address must have the same deployer and package hash.
    * @param extension The global extension address to upgrade
    * @param newExtension The new global extension address to upgrade the extension to
    */
    function upgradeExtension(address extension, address newExtension) external override onlyManager {
        _upgradeExtension(extension, newExtension);
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

        IExtension ext = IExtension(extension);

        string memory interfaceLabel = ext.interfaceLabel();

        ERC1820Client.setInterfaceImplementation(interfaceLabel, address(0));
        ERC1820Implementer._removeInterface(interfaceLabel); // For migration
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
}