pragma solidity ^0.8.0;

import {IPausable} from "./IPausable.sol";
import {ERC20Extension} from "../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {PausableLib} from "./PausableLib.sol";

contract PauseExtension is ERC20Extension, IPausable {

    bytes32 constant PAUSER_ROLE = keccak256("pausable.roles.pausers");

    constructor() {
        _registerFunction(PauseExtension.addPauser.selector);
        _registerFunction(PauseExtension.removePauser.selector);
        _registerFunction(PauseExtension.renouncePauser.selector);
        _registerFunction(PauseExtension.pause.selector);
        _registerFunction(PauseExtension.unpause.selector);
        _registerFunctionName('isPaused()');
        _supportInterface(type(IPausable).interfaceId);
    }
    
    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!this.isPaused(), "Token must not be paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(this.isPaused(), "Token must be paused");
        _;
    }

    modifier onlyPauser() {
        require(hasRole(_msgSender(), PAUSER_ROLE), "Only pausers can use this function");
        _;
    }

    function isPaused() public override view returns (bool) {
        return PausableLib.isPaused();
    }

    function initalize() external override {
        _addRole(_msgSender(), PAUSER_ROLE);
    }

    function pause() external override onlyPauser whenNotPaused {
        PausableLib.pause();
        emit Paused(msg.sender);
    }

    function unpause() external override onlyPauser whenPaused {
        PausableLib.unpause();
        emit Unpaused(msg.sender);
    }

    function addPauser(address account) external override onlyPauser {
        _addPauser(account);
    }

    function removePauser(address account) external override onlyPauser {
        _removePauser(account);
    }

    function renouncePauser() external override {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _addRole(account, PAUSER_ROLE);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _removeRole(account, PAUSER_ROLE);
        emit PauserRemoved(account);
    }

    function validateTransfer(TransferData memory data) external override view returns (bool) {
        bool isPaused = PausableLib.isPaused();

        require(!isPaused, "Transfers are paused");

        return true;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        bool isPaused = PausableLib.isPaused();

        require(!isPaused, "Transfers are paused");

        return true;
    }
}