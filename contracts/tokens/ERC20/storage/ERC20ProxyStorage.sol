pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ERC20ProxyStorage is Context {
    bytes32 constant ERC20_CORE_ADDRESS = keccak256("erc20.proxy.core.address");
    bytes32 constant ERC20_STORAGE_ADDRESS = keccak256("erc20.proxy.storage.address");
    bytes32 constant ERC20_MANAGER_ADDRESS = keccak256("erc20.proxy.manager.address");

    function _setImplementation(address implementation) internal {
        StorageSlot.getAddressSlot(ERC20_CORE_ADDRESS).value = implementation;
    }

    function _setStore(address store) internal {
        StorageSlot.getAddressSlot(ERC20_STORAGE_ADDRESS).value = store;
    }

    function manager() public view returns (address) {
        return StorageSlot.getAddressSlot(ERC20_MANAGER_ADDRESS).value;
    }

    modifier onlyManager {
        require(_msgSender() == manager(), "This function can only be invoked by the manager");
        _;
    }

    function changeManager(address newManager) external onlyManager {
        StorageSlot.getAddressSlot(ERC20_MANAGER_ADDRESS).value = newManager;
    }
}