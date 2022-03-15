pragma solidity ^0.8.0;

import {ERC1820Client} from "../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../erc1820/ERC1820Implementer.sol";
import {TokenRoles} from "../../roles/TokenRoles.sol";
import {DomainAware} from "../../tools/DomainAware.sol";
import {ITokenLogic} from "../../interface/ITokenLogic.sol";
import {ExtensionStorage} from "../../extensions/ExtensionStorage.sol";
import {ITokenProxy} from "../../interface/ITokenProxy.sol";
import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {TransferData} from "../../interface/IToken.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

abstract contract TokenProxy is TokenERC1820Provider, TokenRoles, DomainAware, ITokenProxy {
    using BytesLib for bytes;

    constructor(address logicAddress, address owner) {
        if (owner != address(0) && owner != _msgSender()) {
            transferOwnership(owner);
            StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = owner;
        } else {
            StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = _msgSender();
        }

        ERC1820Client.setInterfaceImplementation(__tokenInterfaceName(), address(this));
        ERC1820Implementer._setInterface(__tokenInterfaceName()); // For migration

        require(logicAddress != address(0), "Logic address must be given");
        require(logicAddress == ERC1820Client.interfaceAddr(logicAddress, __tokenLogicInterfaceName()), "Not registered as a logic contract");

        _setLogic(logicAddress);
    }

    function _getLogicContractAddress() internal view returns (address) {
        return ERC1820Client.interfaceAddr(address(this), __tokenLogicInterfaceName());
    }

    function _setLogic(address logic) internal {
        ERC1820Client.setInterfaceImplementation(__tokenLogicInterfaceName(), logic);
    }

    
    function upgradeTo(address logic, bytes memory data) external override onlyManager {
        _setLogic(logic);

        //invoke the initialize function whenever we upgrade
        (bool success,) = _delegatecall(
            abi.encodeWithSelector(ITokenLogic.initialize.selector, data)
        );

        //Invoke initialize
        require(success, "Logic initializing failed");
    }

    function _delegateCurrentCall() internal {
        _delegatecallAndReturn(_msgData());
    }

    function _staticDelegateCurrentCall() internal view returns (bytes memory results) {
        (, results) = _staticDelegateCall(_msgData());
    }

    modifier delegated {
        _delegateCurrentCall();
        _;
    }

    modifier staticdelegated {
        _staticDelegateCallAndReturn(_msgData());
        _;
    }

    function _delegatecall(bytes memory _calldata) internal returns (bool success, bytes memory result) {
        address logic = _getLogicContractAddress();

        // Forward the external call using call and return any value
        // and reverting if the call failed
        (success, result) = logic.delegatecall{gas: gasleft()}(_calldata);

        if (!success) {
            revert(string(result));
        }
    }

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

    function _fallback() internal virtual {
        if (msg.sig == STATICCALLMAGIC) {
            require(msg.sender == address(this), "STATICCALLMAGIC can only be used by the Proxy");

            bytes memory _calldata = msg.data.slice(4, msg.data.length - 4);
            _delegatecallAndReturn(_calldata);
        } else {
            _delegateCurrentCall();
        }
    }

    // Forward any function not found here to the logic
    fallback() external override payable {
        _fallback();
    }
    
    receive() external override payable {}

    function _domainVersion() internal virtual override view returns (bytes32) {
        return bytes32(uint256(uint160(_getLogicContractAddress())));
    }
}