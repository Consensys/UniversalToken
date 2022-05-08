pragma solidity ^0.8.0;

import {ERC1820Client} from "../../utils/erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../utils/erc1820/ERC1820Implementer.sol";
import {TokenRoles} from "../../utils/roles/TokenRoles.sol";
import {DomainAware} from "../../utils/DomainAware.sol";
import {ITokenLogic} from "../logic/ITokenLogic.sol";
import {ITokenProxy} from "./ITokenProxy.sol";
import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {TransferData} from "../IToken.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

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
abstract contract TokenProxy is TokenERC1820Provider, TokenRoles, DomainAware, ITokenProxy {
    using BytesLib for bytes;

    bytes32 private constant UPGRADING_FLAG_SLOT = keccak256("token.proxy.upgrading");

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
            TokenRoles.transferOwnership(owner);
            StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = owner;
        } else {
            StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = _msgSender();
        }

        ERC1820Client.setInterfaceImplementation(__tokenInterfaceName(), address(this));
        ERC1820Implementer._setInterface(__tokenInterfaceName()); // For migration

        require(logicAddress != address(0), "Logic address must be given");
        require(logicAddress == ERC1820Client.interfaceAddr(logicAddress, __tokenLogicInterfaceName()), "Not registered as a logic contract");

        _setLogic(logicAddress);

        //setup initalize call
        bytes memory data = abi.encode(logicAddress, owner);
        StorageSlot.getUint256Slot(UPGRADING_FLAG_SLOT).value = data.length;

        //invoke the initialize function during deployment
        (bool success,) = _delegatecall(
            abi.encodeWithSelector(ITokenLogic.initialize.selector, data)
        );

        //Check initialize
        require(success, "Logic initializing failed");
    
        StorageSlot.getUint256Slot(UPGRADING_FLAG_SLOT).value = 0;

        emit Upgraded(logicAddress);
    }

    /**
    * @dev Get the current address for the logic contract. This is read from the ERC1820 registry
    * @return address The address of the current logic contract
    */
    function _getLogicContractAddress() private view returns (address) {
        return ERC1820Client.interfaceAddr(address(this), __tokenLogicInterfaceName());
    }

    /**
    * @dev Saves the logic contract address to use for the proxy in the ERC1820 registry and 
    * in the EIP1967 storage slot
    * @notice This should not be called directly. If you wish to change the logic contract,
    * use upgradeTo. This function side-steps some side-effects such as emitting the Upgraded
    * event
    */
    function _setLogic(address logic) internal {
        bytes32 EIP1967_LOCATION = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

        //Update registry
        ERC1820Client.setInterfaceImplementation(__tokenLogicInterfaceName(), logic);
        
        //Update EIP1967 Storage Slot
        StorageSlot.getAddressSlot(EIP1967_LOCATION).value = logic;
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
        
        StorageSlot.getUint256Slot(UPGRADING_FLAG_SLOT).value = data.length;

        _setLogic(logic);

        //invoke the initialize function whenever we upgrade
        (bool success,) = _delegatecall(
            abi.encodeWithSelector(ITokenLogic.initialize.selector, data)
        );

        //Invoke initialize
        require(success, "Logic initializing failed");

        StorageSlot.getUint256Slot(UPGRADING_FLAG_SLOT).value = 0;

        emit Upgraded(logic);
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
        if (msg.sig == STATICCALLMAGIC) {
            require(msg.sender == address(this), "STATICCALLMAGIC can only be used by the Proxy");

            bytes memory _calldata = msg.data.slice(4, msg.data.length - 4);
            _delegatecallAndReturn(_calldata);
        } else {
            _delegateCurrentCall();
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
    * @dev Child contracts may override this function
    * @notice Receive ether
    */
    receive() external override virtual payable {}

    /**
    * @notice The current domain version of the TokenProxy is the address of
    * the current logic contract.
    * @inheritdoc DomainAware
    */
    function _domainVersion() internal virtual override view returns (bytes32) {
        return bytes32(uint256(uint160(_getLogicContractAddress())));
    }
}