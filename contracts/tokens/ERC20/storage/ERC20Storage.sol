pragma solidity ^0.8.0;

import {Diamond} from "../../../tools/diamond/Diamond.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20Storage} from "./IERC20Storage.sol";
import {ERC1820Client} from "../../../tools/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../interface/ERC1820Implementer.sol";
import {ProxyContext} from "../../../tools/context/ProxyContext.sol";
import {ERC1820Client} from "../../../tools/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../interface/ERC1820Implementer.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20ExtendableRouter} from "../extensions/ERC20ExtendableRouter.sol";
import {ERC20ExtendableLib} from "../extensions/ERC20ExtendableLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Storage is IERC20Storage, ProxyContext, ERC20, ERC1820Client, ERC1820Implementer, ERC20ExtendableRouter {
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";
    string constant internal ERC20_STORAGE_INTERFACE_NAME = "ERC20TokenStorage";
    
    constructor(
        address token, 
        string memory name_, 
        string memory symbol_
    ) ERC20(name_, symbol_) Diamond(address(0)) {
        _setCallSite(token);
        
        ERC1820Client.setInterfaceImplementation(ERC20_STORAGE_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_STORAGE_INTERFACE_NAME); // For migration
    }

    modifier onlyToken {
        require(msg.sender == _callsiteAddress(), "Unauthorized");
        _;
    }

    function _getCurrentImplementationAddress() internal view returns (address) {
        address token = _callsiteAddress();
        return ERC1820Client.interfaceAddr(token, ERC20_LOGIC_INTERFACE_NAME);
    }

    function _msgSender() internal view override(Context, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override(ERC20, IERC20) onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
        
        return true;
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override(ERC20, IERC20) onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
        
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override(ERC20, IERC20) onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public override(ERC20, IERC20Storage) onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public override(ERC20, IERC20Storage) onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
    }

    function burn(uint256 amount) external override onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
    }

    function burnFrom(address account, uint256 amount) external override onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
    }

    function mint(address receipient, uint256 amoount) external override onlyToken returns (bool) {
        address currentImplementation = _getCurrentImplementationAddress();
        _delegate(currentImplementation);
    }

    function registerExtension(address extension) external override onlyToken returns (bool) {
        return _registerExtension(extension);
    }

    function removeExtension(address extension) external override onlyToken returns (bool) {
        return _removeExtension(extension);
    }

    function disableExtension(address extension) external override onlyToken returns (bool) {
        return _disableExtension(extension);
    }

    function enableExtension(address extension) external override onlyToken returns (bool) {
        return _enableExtension(extension);
    }

    function allExtensions() external override view onlyToken returns (address[] memory) {
        //To return all the extensions, we'll read directly from the ERC20CoreExtendableBase's storage struct
        //since it's stored here at the proxy
        //The ERC20ExtendableLib library offers functions to do this
        return ERC20ExtendableLib._allExtensions();
    }
}