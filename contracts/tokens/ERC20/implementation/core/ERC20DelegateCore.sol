pragma solidity ^0.8.0;

import {ERC20Core} from "./ERC20Core.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IERC20Storage} from "../../storage/IERC20Storage.sol";

/**
* @dev Contract to be used with an ERC20DelegateProxy. This contract assumes it will be delegatecall'ed 
* by the ERC20DelegateProxy and as such will reference the same storage pointer the ERC20DelegateProxy uses
* for the ERC20Storage contract. This contract will confirm the correct context by ensuring this storage 
* pointer exists (has a value that is non-zero) and that the ERC20Storage address it points to accepts
* us as a writer
*/
contract ERC20DelegateCore is ERC20Core {
    bytes32 constant ERC20_STORAGE_ADDRESS = keccak256("erc20.proxy.storage.address");

    constructor() ERC20Core(ZERO_ADDRESS, ZERO_ADDRESS) { }

    function _getStorageLocation() internal override pure returns (bytes32) {
        return ERC20_STORAGE_ADDRESS;
    }

    function _confirmContext() internal override view returns (bool) {
        IERC20Storage store = _getStorageContract();
        return address(store) != ZERO_ADDRESS && store.allowWriteFrom(address(this));
    }
}