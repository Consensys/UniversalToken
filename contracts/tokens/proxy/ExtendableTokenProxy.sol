pragma solidity ^0.8.0;

import {TokenProxy} from "./TokenProxy.sol";
import {IExtendableTokenProxy} from "./IExtendableTokenProxy.sol";
import {ExtendableProxy} from "../extension/ExtendableProxy.sol";
import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ExtensionProxy} from "../../extensions/ExtensionProxy.sol";
import {ITokenProxy} from "./ITokenProxy.sol";
import {IDiamondLoupe} from "../../interface/IDiamondLoupe.sol";

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
abstract contract ExtendableTokenProxy is TokenProxy, ExtendableProxy, IExtendableTokenProxy, IDiamondLoupe {
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

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external override view returns (Facet[] memory facets_) {
        address[] storage extensions = _allExtensionsRegistered();
        facets_ = new Facet[](extensions.length);

        for (uint i = 0; i < facets_.length; i++) {
            facets_[i] = Facet(
                extensions[i],
                facetFunctionSelectors(extensions[i])
            );
        }
    }

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) public override view returns (bytes4[] memory facetFunctionSelectors_) {
        return _addressToExtensionData(_facet).externalFunctions;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external override view returns (address[] memory facetAddresses_) {
        return _allExtensionsRegistered();
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external override view returns (address facetAddress_) {
        return _functionToExtensionProxyAddress(_functionSelector);
    }
}