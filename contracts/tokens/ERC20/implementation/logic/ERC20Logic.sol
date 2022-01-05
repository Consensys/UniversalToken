pragma solidity ^0.8.0;

import {ERC20LogicExtendable} from "./ERC20LogicExtendable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IERC20Storage} from "../../storage/IERC20Storage.sol";

/**
* @dev Contract to be used with an ERC20Proxy. This contract assumes it will be delegatecall'ed 
* by the ERC20Proxy and as such will reference the same storage pointer the ERC20Proxy uses
* for the ERC20Storage contract. This contract will confirm the correct context by ensuring this storage 
* pointer exists (has a value that is non-zero) and that the ERC20Storage address it points to accepts
* us as a writer
*/
contract ERC20Logic is ERC20LogicExtendable {
    bytes32 constant ERC20_STORAGE_ADDRESS = keccak256("erc20.proxy.storage.address");

    constructor() ERC20LogicExtendable(ZERO_ADDRESS, ZERO_ADDRESS) { }

    function _getStorageLocation() internal override virtual pure returns (bytes32) {
        return ERC20_STORAGE_ADDRESS;
    }

    function _confirmContext() internal override virtual view returns (bool) {
        IERC20Storage store = _getStorageContract();
        return address(store) != ZERO_ADDRESS && store.allowWriteFrom(address(this));
    }

    function _getProxyAddress() internal override virtual view returns (address) {
        return address(this); //we are also the proxy with delegatecall
    }
}