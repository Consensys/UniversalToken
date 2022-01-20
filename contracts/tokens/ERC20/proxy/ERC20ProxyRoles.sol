pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {Roles} from "../../../roles/Roles.sol";
import {RolesBase} from "../../../roles/RolesBase.sol";
import {ExtensionLib} from "../../extension/ExtensionLib.sol";

abstract contract ERC20ProxyRoles is RolesBase, Context {
    using Roles for Roles.Role;

    bytes32 constant ERC20_ALLOW_BURN = keccak256("erc20.proxy.core.burn");
    bytes32 constant ERC20_ALLOW_MINT = keccak256("erc20.proxy.core.mint");
    bytes32 constant ERC20_OWNER = keccak256("erc20.proxy.core.owner");
    bytes32 constant ERC20_MINTER_ROLE = keccak256("erc20.proxy.core.mint.role");
    bytes32 constant ERC20_MANAGER_ADDRESS = keccak256("erc20.proxy.manager.address");
    bytes32 constant ERC20_CONTROLLER_ROLE = keccak256("erc20.proxy.controller.address");
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    modifier onlyManager {
        require(_msgSender() == manager(), "This function can only be invoked by the manager");
        _;
    }

    modifier onlyMinter {
        require(isMinter(_msgSender()), "This function can only be invoked by a minter");
        _;
    }

    modifier onlyControllers {
        require(isController(_msgSender()), "This function can only be invoked by a controller");
        _;
    }

    modifier onlyExtensions {
        address extension = _msgSender();
        require(ExtensionLib._isActiveExtension(extension), "Only extensions can call");
        _;
    }
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function manager() public view returns (address) {
        return StorageSlot.getAddressSlot(ERC20_MANAGER_ADDRESS).value;
    }

    function isController(address caller) public view returns (bool) {
        return hasRole(caller, ERC20_CONTROLLER_ROLE);
    }

    function isMinter(address caller) public view returns (bool) {
        return hasRole(caller, ERC20_MINTER_ROLE);
    }

    function addController(address caller) public onlyControllers {
        _addRole(caller, ERC20_CONTROLLER_ROLE);
    }

    function removeController(address caller) public onlyControllers {
        _addRole(caller, ERC20_CONTROLLER_ROLE);
    }

    function addMinter(address caller) public onlyMinter {
        _addRole(caller, ERC20_MINTER_ROLE);
    }

    function removeMinter(address caller) public onlyMinter {
        _removeRole(caller, ERC20_MINTER_ROLE);
    }

    function changeManager(address newManager) external onlyManager {
        StorageSlot.getAddressSlot(ERC20_MANAGER_ADDRESS).value = newManager;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return StorageSlot.getAddressSlot(ERC20_OWNER).value;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = owner();
        StorageSlot.getAddressSlot(ERC20_OWNER).value = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}