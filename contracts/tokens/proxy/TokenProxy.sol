pragma solidity ^0.8.0;

import {TokenRoles} from "../../roles/TokenRoles.sol";
import {DomainAware} from "../../tools/DomainAware.sol";
import {ITokenLogic} from "../logic/ITokenLogic.sol";
import {ITokenProxy} from "./ITokenProxy.sol";
import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";
import {StorageSlotUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/utils/StorageSlotUpgradeable.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {Errors} from "../../helpers/Errors.sol";
import {ExtendableDiamond} from "../extension/ExtendableDiamond.sol";
import {IExtension} from "../../interface/IExtension.sol";

/**
* @title Token Proxy base Contract
* @notice This should be inherited by the token proxy
* @dev A generic proxy contract to be used by any token standard. The final token proxy
* contract should also inherit from a TokenERC1820Provider contract or implement those functions.
* This contract handles roles, domain, logic contract tracking (through ERC1820 + EIP1967),
* upgrading, and has several internal functions to delegatecall to the logic contract.
*
* This contract also has a fallback function to forward any un-routed calls to the current logic
* contract
*
* The domain version of the TokenProxy will be the current address of the logic contract. The domain
* name must be implemented by the final token proxy.
*/
abstract contract TokenProxy is TokenERC1820Provider, TokenRoles, DomainAware, ExtendableDiamond, ITokenProxy {
    using BytesLib for bytes;

    bytes32 private constant UPGRADING_FLAG_SLOT = keccak256("consensys.contracts.token.storage.logic.upgrading");
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
    * @dev This event is invoked when the logic contract is upgraded to a new contract
    * address.
    * @param logic The new logic contract address
    * @notice Used by the EIP1967 standard
    */
    event Upgraded(address indexed logic);

    /**
    * @dev Sets up the proxy by initalizing the owner + manager roles, as well as
    * setting the logic contract. This will also register the token interface
    * with the ERC1820 registry.
    * @param logicAddress The address to use for the logic contract. Must be non-zero
    * @param owner The address to use as the owner + manager.
    */
    constructor(address logicAddress, address owner) {
        if (owner != address(0) && owner != _msgSender()) {
            transferOwnership(owner);
            StorageSlotUpgradeable.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = owner;
        } else {
            StorageSlotUpgradeable.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = _msgSender();
        }

        setInterfaceImplementation(__tokenInterfaceName(), address(this));
        _setInterface(__tokenInterfaceName()); // For migration

        setInterfaceImplementation(EXTENDABLE_INTERFACE_NAME, address(this));
        _setInterface(EXTENDABLE_INTERFACE_NAME); // For migration

        require(logicAddress != address(0), Errors.NO_LOGIC_ADDRESS);
        require(logicAddress == interfaceAddr(logicAddress, __tokenLogicInterfaceName()), "Not registered as a logic contract");

        _setLogic(logicAddress);

        //Extensions can do controlled transfers
        _addRole(address(this), TOKEN_CONTROLLER_ROLE);

        //setup initalize call
        bytes memory data = abi.encode(logicAddress, owner);
        StorageSlotUpgradeable.getUint256Slot(UPGRADING_FLAG_SLOT).value = data.length;

        //invoke the initialize function during deployment
        (bool success,) = _delegatecall(
            abi.encodeWithSelector(ITokenLogic.initialize.selector, data)
        );
        
        //Check initialize
        require(success, Errors.LOGIC_INIT_FAILED);
    
        StorageSlotUpgradeable.getUint256Slot(UPGRADING_FLAG_SLOT).value = 0;
        
        emit Upgraded(logicAddress);
    }

    /**
    * @dev Get the current address for the logic contract. This is read from the ERC1820 registry
    * @return address The address of the current logic contract
    */
    function _getLogicContractAddress() private view returns (address) {
        return interfaceAddr(address(this), __tokenLogicInterfaceName());
    }

    /**
    * @dev Saves the logic contract address to use for the proxy in the ERC1820 registry and 
    * in the EIP1967 storage slot
    * @notice This should not be called directly. If you wish to change the logic contract,
    * use upgradeTo. This function side-steps some side-effects such as emitting the Upgraded
    * event
    */
    function _setLogic(address logic) internal {
        bytes32 EIP1967_LOCATION = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);

        //Update registry
        setInterfaceImplementation(__tokenLogicInterfaceName(), logic);
        
        //Update EIP1967 Storage Slot
        StorageSlotUpgradeable.getAddressSlot(EIP1967_LOCATION).value = logic;
    }
    
    /**
    * @dev Upgrade the TokenProxy logic contract. Can only be executed by the current manager address
    * @notice Perform an upgrade on the proxy and replace the current logic
    * contract with a new one. You must provide the new address of the
    * logic contract and (optionally) some arbitrary data to pass to
    * the logic contract's initialize function.
    * @param logic The address of the new logic contract
    * @param data Any arbitrary data, will be passed to the new logic contract's initialize function
    */
    function upgradeTo(address logic, bytes memory data) external override onlyManager {
        if (data.length == 0) {
            data = bytes("f");
        }
        
        StorageSlotUpgradeable.getUint256Slot(UPGRADING_FLAG_SLOT).value = data.length;

        _setLogic(logic);

        //invoke the initialize function whenever we upgrade
        (bool success,) = _delegatecall(
            abi.encodeWithSelector(ITokenLogic.initialize.selector, data)
        );

        //Invoke initialize
        require(success, Errors.LOGIC_INIT_FAILED);

        StorageSlotUpgradeable.getUint256Slot(UPGRADING_FLAG_SLOT).value = 0;

        emit Upgraded(logic);
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
    * @param extension The global extension address to register
    */
    function registerExtension(address extension) external override onlyManager {
        _registerExtension(extension);

        IExtension ext = IExtension(extension);

        string memory interfaceLabel = ext.interfaceLabel();

        setInterfaceImplementation(interfaceLabel, address(this));
        _setInterface(interfaceLabel); // For migration
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

        setInterfaceImplementation(interfaceLabel, address(0));
        _removeInterface(interfaceLabel); // For migration
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
    * @dev Forward the current call to the logic contract. This will
    * use delegatecall to forward the current call to the current logic
    * contract. This function returns & exits the current call
    */
    function _delegateCurrentCall() internal {
        _delegatecallAndReturn(_msgData());
    }

    /**
    * @dev Forward the current staticcall to the logic contract. This
    * function works in both a read (STATICCALL) and write (CALL) call context.
    * The return data from the staticcall is returned as arbitrary data. It is
    * up to the invoker to decode the data (hint: Use BytesLib)
    * @return results The return data from the result of the STATICCALL to the logic contract.
    */
    function _staticDelegateCurrentCall() internal view returns (bytes memory results) {
        (, results) = _staticDelegateCall(_msgData());
    }

    /**
    * @dev A function modifier that will always forward the function
    * definiation to the current logic contract. The body of the function
    * is never invoked, so it can remain blank.
    *
    * Any data returned by the logic contract is returned to the current caller
    */
    modifier delegated {
        _delegateCurrentCall();
        _;
    }

    /**
    * @dev A function modifier that will always forward the view function
    * definiation to the current logic contract. The body of the view function
    * is never invoked, so it can remain blank.
    *
    * Any data returned by the logic contract is returned to the current caller
    */
    modifier staticdelegated {
        _staticDelegateCallAndReturn(_msgData());
        _;
    }

    /**
    * @dev Make a delegatecall to the current logic contract and return any returndata. If
    * the call fails/reverts then this call reverts. 
    * @param _calldata The calldata to use in the delegatecall
    * @return success Whethter the delegatecall was successful
    * @return result Any returndata resulting from the delegatecall
    */
    function _delegatecall(bytes memory _calldata) internal returns (bool success, bytes memory result) {
        address logic = _getLogicContractAddress();

        // Forward the external call using call and return any value
        // and reverting if the call failed
        (success, result) = logic.delegatecall{gas: gasleft()}(_calldata);

        if (!success) {
            revert(string(result));
        }
    }

    /**
    * @dev Make a delegatecall to the current logic contract, returning any returndata to the
    * current caller.
    * @param _calldata The calldata to use in the delegatecall
    */
    function _delegatecallAndReturn(bytes memory _calldata) internal {
        address logic = _getLogicContractAddress();

        // Forward the external call using call and return any value
        // and reverting if the call failed
        assembly {
            // execute function call
            let result := delegatecall(gas(), logic, add(_calldata, 0x20), mload(_calldata), 0, 0)
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
    * @dev Used by _staticcall and _staticcallAndReturn
    */
    bytes4 private constant STATICCALLMAGIC = hex"ffffffff";


    /**
    * @dev Make a static call (read-only call) to the logic contract and return this call. This
    * effectively uses the logic contract code to read from our storage.
    * This is done by using by doing a delayed delegatecall inside our fallback function
    * We'll do this by invoking a STATICCALL on ourselves with the following data
    * <STATICCALLMAGIC> + _calldata
    * In our fallback function (because we dont have a function declared with the 
    * STATICCALLMAGIC selector), the STATICCALLMAGIC is trimmed and the rest of
    * the provided _calldata is passed to DELEGATECALL
    *
    * This function ends the current call and returns the data returned by STATICCALL. To
    * just return the data returned by STATICCALL without ending the current call, use _staticcall
    * @param _calldata The calldata to send with the STATICCALL
    */
    function _staticDelegateCallAndReturn(bytes memory _calldata) internal view {
        bytes memory finalData = abi.encodePacked(STATICCALLMAGIC, _calldata);
        address self = address(this);

        // Forward the external call using call and return any value
        // and reverting if the call failed
        assembly {
            // execute function call
            let result := staticcall(gas(), self, add(finalData, 0x20), mload(_calldata), 0, 0)
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
    * @dev Make a static call (read-only call) to the logic contract. This
    * effectively uses the logic contract code to read from our storage.
    * This is done by using by doing a delayed delegatecall inside our fallback function
    * We'll do this by invoking a STATICCALL on ourselves with the following data
    * <STATICCALLMAGIC> + _calldata
    * In our fallback function (because we dont have a function declared with the 
    * STATICCALLMAGIC selector), the STATICCALLMAGIC is trimmed and the rest of
    * the provided _calldata is passed to DELEGATECALL
    * @param _calldata The calldata to send with the STATICCALL
    * @return success Whether the STATICCALL was successful. If the call was not successful then
    * a revert is thrown with the data returned by the STATICCALL
    * @return result The result of the STATICCALL
    */
    function _staticDelegateCall(bytes memory _calldata) internal view returns (bool success, bytes memory result) {
        bytes memory finalData = abi.encodePacked(STATICCALLMAGIC, _calldata);

        // Forward the external call using call and return any value
        // and reverting if the call failed
        (success, result) = address(this).staticcall{gas: gasleft()}(finalData);

        if (!success) {
            revert(string(result));
        }
    }

    /**
    * @dev The default fallback function the TokenProxy will use. Child contracts
    * must override this function to add additional functionality to the fallback function of
    * the proxy.
    */
    function _fallback() internal virtual {
        bool isExt = _isExtensionFunction(msg.sig);

        if (isExt) {
            _invokeExtensionFunction();
        } else {
            if (msg.sig == STATICCALLMAGIC) {
                require(msg.sender == address(this), Errors.UNAUTHORIZED_FOR_STATICCALL_MAGIC);

                bytes memory _calldata = msg.data.slice(4, msg.data.length - 4);
                _delegatecallAndReturn(_calldata);
            } else {
                _delegateCurrentCall();
            }
        }
    }

    /**
    * @notice Forward any function not found in the TokenProxy contract (or any child contracts)
    * to the current logic contract.
    */
    fallback() external override payable {
        _fallback();
    }

    /**
    * @notice The current domain version of the TokenProxy is the address of
    * the current logic contract.
    * @inheritdoc DomainAware
    */
    function _domainVersion() internal virtual override view returns (bytes32) {
        return bytes32(uint256(uint160(_getLogicContractAddress())));
    }
}