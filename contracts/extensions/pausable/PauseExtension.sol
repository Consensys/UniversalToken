pragma solidity ^0.8.0;

import {IPausable} from "./IPausable.sol";
import {TokenExtension, TransferData} from "../TokenExtension.sol";

contract PauseExtension is TokenExtension, IPausable {

    bytes32 constant PAUSER_ROLE = keccak256("consensys.contracts.token.ext.storage.pausable.roles.pausers");

    bytes32 constant PAUSE_EXTSTATE_SLOT = keccak256("consensys.contracts.token.ext.storage.pausable.state");

    struct PauseExtState {
        bool _isPaused;
        mapping(address => bool) _pausedFor;
    }

    /**
    * @dev The ProxyData struct stored in this registered Extension instance.
    */
    function _pauseState() internal pure returns (PauseExtState storage ds) {
        bytes32 position = PAUSE_EXTSTATE_SLOT;
        assembly {
            ds.slot := position
        }
    }

    constructor() {
        _registerFunction(PauseExtension.addPauser.selector);
        _registerFunction(PauseExtension.removePauser.selector);
        _registerFunction(PauseExtension.renouncePauser.selector);
        _registerFunction(PauseExtension.pause.selector);
        _registerFunction(PauseExtension.unpause.selector);
        _registerFunction(PauseExtension.pauseFor.selector);
        _registerFunction(PauseExtension.unpauseFor.selector);
        
        _registerFunctionName('isPaused()');
        _registerFunctionName('isPausedFor(address)');

        _supportInterface(type(IPausable).interfaceId);

        _supportsAllTokenStandards();

        _setPackageName("net.consensys.tokenext.PauseExtension");
        _setVersion(1);
        _setInterfaceLabel("PauseExtension");
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
        return _pauseState()._isPaused;
    }

    function initialize() external override {
        _addRole(_msgSender(), PAUSER_ROLE);
        _listenForTokenTransfers(this.onTransferExecuted);
        _listenForTokenApprovals(this.onTransferExecuted);
    }

    function pause() external override onlyPauser whenNotPaused {
        _pauseState()._isPaused = true;
        emit Paused(_msgSender());
    }

    function unpause() external override onlyPauser whenPaused {
        _pauseState()._isPaused = false;
        emit Unpaused(_msgSender());
    }

    function isPausedFor(address caller) public override view returns (bool) {
        return isPaused() || _pauseState()._pausedFor[caller];
    }

    function pauseFor(address caller) external override onlyPauser {
        _pauseState()._pausedFor[caller] = true;
    }

    function isPauser(address caller) external override view returns (bool) {
        return hasRole(caller, PAUSER_ROLE);
    }

    function unpauseFor(address caller) external override onlyPauser {
        _pauseState()._pausedFor[caller] = false;
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

    function onTransferExecuted(TransferData memory data) external eventGuard returns (bool) {
        bool isPaused = isPausedFor(data.from);

        require(!isPaused, "Transfers are paused");

        return true;
    }
}