pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/utils/ContextUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {Roles} from "./Roles.sol";
import {RolesBase} from "./RolesBase.sol";
import {ITokenRoles} from "../interface/ITokenRoles.sol";
import {TokenRolesConstants} from "./TokenRolesConstants.sol";

/**
* @title Token Roles
* @notice A base contract for handling token roles. 
* @dev This contract is responsible for the storage and API of access control
* roles that all tokens should implement. This includes the following roles
*  * Owner
*     - A single owner address of the token, as implemented as Ownerable
*  * Minter
      - The access control role that allows an address to mint tokens
*  * Manager
*     - The single manager address of the token, can manage extensions
*  * Controller
*     - The access control role that allows an address to perform controlled-transfers
* 
* This contract also handles the storage of the burning/minting toggling.
*/
abstract contract TokenRoles is TokenRolesConstants, ITokenRoles, RolesBase, ContextUpgradeable {
    using Roles for Roles.Role;
    
    /**
    * @notice This event is triggered when transferOwnership is invoked
    * @param previousOwner The previous owner before the transfer
    * @param newOwner The new owner of the token
    */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
    * @notice This event is triggered when the manager address is updated. This
    * can occur when transferOwnership is invoked or when changeManager is invoked.
    * This event name is taken from EIP1967
    * @param previousAdmin The previous manager before the update
    * @param newAdmin The new manager of the token
    */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
    * @dev A function modifier that will only allow the current token manager to
    * invoke the function
    */
    modifier onlyManager {
        require(_msgSender() == manager(), "This function can only be invoked by the manager");
        _;
    }

    /**
    * @dev A function modifier that will only allow addresses with the Minter role granted
    * to invoke the function
    */
    modifier onlyMinter {
        require(isMinter(_msgSender()), "This function can only be invoked by a minter");
        _;
    }

    /**
    * @dev A function modifier that will only allow addresses with the Controller role granted
    * to invoke the function
    */
    modifier onlyControllers {
        require(isController(_msgSender()), "This function can only be invoked by a controller");
        _;
    }
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
    * @notice Returns the current token manager
    */
    function manager() public override view returns (address) {
        return StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value;
    }

    /**
    * @notice Returns true if `caller` has the Controller role granted
    */
    function isController(address caller) public override view returns (bool) {
        return hasRole(caller, TOKEN_CONTROLLER_ROLE);
    }

    /**
    * @notice Returns true if `caller` has the Minter role granted
    */
    function isMinter(address caller) public override view returns (bool) {
        return hasRole(caller, TOKEN_MINTER_ROLE);
    }

    /**
    * @notice Grant the Controller role to `caller`. Only addresses with
    * the Controller role granted may invoke this function
    * @param caller The address to grant the Controller role to
    */
    function addController(address caller) public override onlyControllers {
        _addRole(caller, TOKEN_CONTROLLER_ROLE);
    }

    /**
    * @notice Remove the Controller role from `caller`. Only addresses with
    * the Controller role granted may invoke this function
    * @param caller The address to remove the Controller role from
    */
    function removeController(address caller) public override onlyControllers {
        _removeRole(caller, TOKEN_CONTROLLER_ROLE);
    }

    /**
    * @notice Grant the Minter role to `caller`. Only addresses with
    * the Minter role granted may invoke this function
    * @param caller The address to grant the Minter role to
    */
    function addMinter(address caller) public override onlyMinter {
        _addRole(caller, TOKEN_MINTER_ROLE);
    }

    /**
    * @notice Remove the Minter role from `caller`. Only addresses with
    * the Minter role granted may invoke this function
    * @param caller The address to remove the Minter role from
    */
    function removeMinter(address caller) public override onlyMinter {
        _removeRole(caller, TOKEN_MINTER_ROLE);
    }

    /**
    * @notice Change the current token manager. Only the current token manager
    * can set a new token manager.
    * @dev This function is also invoked if transferOwnership is invoked
    * when the current token owner is also the current manager. 
    */
    function changeManager(address newManager) public override onlyManager {
        _changeManager(newManager);
    }

    function _changeManager(address newManager) private {
        address oldManager = manager();
        StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = newManager;
        
        emit AdminChanged(oldManager, newManager);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public override view virtual returns (address) {
        return StorageSlot.getAddressSlot(TOKEN_OWNER).value;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public override virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @notice Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * If the current owner is also the current manager, then the manager address
     * is also updated to be the new owner
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) public override virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * If the current owner is also the current manager, then the manager address
     * is also updated to be the new owner
     * @param newOwner The address of the new owner
     */
    function _setOwner(address newOwner) private {
        address oldOwner = owner();
        StorageSlot.getAddressSlot(TOKEN_OWNER).value = newOwner;
        if (oldOwner == manager()) {
            _changeManager(newOwner);
        }
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}