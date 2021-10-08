pragma solidity ^0.8.0;

import {IERC20Extension, TransferData} from "../IERC20Extension.sol";
import {Roles} from "../../roles/Roles.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract PauseExtension is IERC20Extension {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);
    event Paused(address account);
    event Unpaused(address account);

    bytes32 constant IS_PAUSED_SLOT = keccak256("ext.pause");
    bytes32 constant PAUSER_ROLE = keccak256("roles.pausers");

    modifier onlyPauser() {
        require(Roles.roleStorage(PAUSER_ROLE).has(msg.sender), "Only pausers can use this function");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!isPaused(), "Token must not be paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(isPaused(), "Token must be paused");
        _;
    }

    function isPaused() public returns (bool) {
        return StorageSlot.getBooleanSlot(IS_PAUSED_SLOT).value;
    }

    function initalize() external override {
        StorageSlot.getBooleanSlot(IS_PAUSED_SLOT).value = false;
        Roles.roleStorage(PAUSER_ROLE).add(msg.sender);
    }

    function pause() external onlyPauser whenNotPaused {
        StorageSlot.getBooleanSlot(IS_PAUSED_SLOT).value = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyPauser whenPaused {
        StorageSlot.getBooleanSlot(IS_PAUSED_SLOT).value = false;
        emit Unpaused(msg.sender);
    }

    function addPauser(address account) external onlyPauser {
        _addPauser(account);
    }

    function removePauser(address account) external onlyPauser {
        _removePauser(account);
    }

    function renouncePauser() external {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        Roles.roleStorage(PAUSER_ROLE).add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        Roles.roleStorage(PAUSER_ROLE).remove(account);
        emit PauserRemoved(account);
    }

    function validateTransfer(TransferData memory data) external override view returns (bool) {
        bool isPaused = StorageSlot.getBooleanSlot(IS_PAUSED_SLOT).value;

        require(!isPaused, "Transfers are paused");

        return true;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        bool isPaused = StorageSlot.getBooleanSlot(IS_PAUSED_SLOT).value;

        require(!isPaused, "Transfers are paused");

        return true;
    }

    function externalFunctions() external override pure returns (bytes4[] memory) {
        bytes4[] memory funcSigs = new bytes4[](5);
        
        funcSigs[0] = PauseExtension.addPauser.selector;
        funcSigs[1] = PauseExtension.removePauser.selector;
        funcSigs[2] = PauseExtension.renouncePauser.selector;
        funcSigs[3] = PauseExtension.pause.selector;
        funcSigs[4] = PauseExtension.unpause.selector;

        return funcSigs;
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
        return interfaceId == type(IERC20Extension).interfaceId;
    }
}