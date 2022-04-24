pragma solidity ^0.8.0;

import {IRegisteredFunctionLookup} from "../interface/IRegisteredFunctionLookup.sol";

abstract contract RegisteredFunctionLookup is IRegisteredFunctionLookup {
    bytes32 constant FUNC_DATA_SLOT = keccak256("consensys.contracts.token.ext.storage.meta");

    /**
    * @dev The data structure holding all the registered function selectors this contract has. We register function
    * selectors here so it can be looked up by TokenProxy when building a Diamond Facet.
    * Function selectors should only be added inside the contract constructor, therefore written access
    * to the storage is prohibited outside of a constructor.
    * @param _exposedFuncSigs An array of function selectors this Extension exposes to a Proxy or Diamond
    */
    struct RegisteredFunctions {
        bytes4[] _exposedFuncSigs;
    }

    /**
    * @dev The ProxyData struct stored in this registered Extension instance.
    */
    function __registeredFunctionData() private pure returns (RegisteredFunctions storage ds) {
        bytes32 position = FUNC_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function __isInsideConstructorCall() internal view returns (bool) {
        uint size;
        address addr = address(this);
        assembly { size := extcodesize(addr) }
        return size == 0;
    }

    function _registerFunctionName(string memory selector) internal {
        _registerFunction(bytes4(keccak256(abi.encodePacked(selector))));
    }

    function _registerFunction(bytes4 selector) internal {
        require(__isInsideConstructorCall(), "Function must be called inside the constructor");
        __registeredFunctionData()._exposedFuncSigs.push(selector);
    }

    
    function externalFunctions() external override view returns (bytes4[] memory) {
        return __registeredFunctionData()._exposedFuncSigs;
    }
} 