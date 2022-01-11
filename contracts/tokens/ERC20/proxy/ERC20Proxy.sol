pragma solidity ^0.8.0;

import {IERC20Storage} from "../storage/IERC20Storage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20ProxyRoles} from "./ERC20ProxyRoles.sol";
import {DomainAware} from "../../../tools/DomainAware.sol";
import {ERC1820Client} from "../../../tools/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../interface/ERC1820Implementer.sol";

abstract contract ERC20Proxy is IERC20Metadata, ERC20ProxyRoles, DomainAware, ERC1820Client, ERC1820Implementer {
    string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
    string constant internal ERC20_STORAGE_INTERFACE_NAME = "ERC20TokenStorage";
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";

    constructor(bool allowMint, bool allowBurn, address owner) {
        StorageSlot.getAddressSlot(ERC20_MANAGER_ADDRESS).value = msg.sender;

        if (owner != _msgSender()) {
            transferOwnership(owner);
        }

        _toggleMinting(allowMint);
        _toggleBurning(allowBurn);

        ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_INTERFACE_NAME); // For migration
    }

    function _getStorageContract() internal view returns (IERC20Storage) {
        return IERC20Storage(
            ERC1820Client.interfaceAddr(address(this), ERC20_STORAGE_INTERFACE_NAME)
        );
    }

    function _getImplementationContract() internal view returns (address) {
        ERC1820Client.interfaceAddr(address(this), ERC20_LOGIC_INTERFACE_NAME);
    }

    function _setImplementation(address implementation) internal {
        ERC1820Client.setInterfaceImplementation(ERC20_LOGIC_INTERFACE_NAME, implementation);
    }

    function _setStorage(address store) internal {
        ERC1820Client.setInterfaceImplementation(ERC20_STORAGE_INTERFACE_NAME, store);
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public override view returns (uint256) {
        return _getStorageContract().totalSupply();
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public override view returns (uint256) {
        return _getStorageContract().balanceOf(account);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public override view returns (string memory) {
        if (address(_getStorageContract()) == address(0)) {
            return "";
        }
        return _getStorageContract().name();
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public override view returns (string memory) {
        if (address(_getStorageContract()) == address(0)) {
            return "";
        }
        return _getStorageContract().symbol();
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public override view returns (uint8) {
        return _getStorageContract().decimals();
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual onlyMinter mintingEnabled returns (bool) {
        bool result = _mint(to, amount);
        if (result) {
            emit Transfer(address(0), to, amount);
        }
        return result;
    }

        /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual burningEnabled returns (bool) {
        bool result = _burn(amount);
        if (result) {
            emit Transfer(_msgSender(), address(0), amount);
        }
        return result;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual burningEnabled returns (bool) {
        bool result = _burnFrom(account, amount);
        if (result) {
            emit Transfer(account, address(0), amount);
        }
        return result;
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        bool result = _transfer(recipient, amount);
        if (result) {
            emit Transfer(_msgSender(), recipient, amount);
        }
        return result;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) public override view returns (uint256) {
        return _getStorageContract().allowance(owner, spender);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        bool result = _approve(spender, amount);
        if (result) {
            emit Approval(_msgSender(), spender, amount);
        }
        return result;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        bool result = _transferFrom(sender, recipient, amount);

        if (result) {
            emit Transfer(sender, recipient, amount);
            uint256 allowanceAmount = _getStorageContract().allowance(sender, _msgSender());
            emit Approval(sender, _msgSender(), allowanceAmount);
        }
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
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        bool result = _increaseAllowance(spender, addedValue);

        if (result) {
            uint256 allowanceAmount = _getStorageContract().allowance(_msgSender(), spender);
            emit Approval(_msgSender(), spender, allowanceAmount);
        }
        return result;
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        bool result = _decreaseAllowance(spender, subtractedValue);
        if (result) {
            uint256 allowanceAmount = _getStorageContract().allowance(_msgSender(), spender);
            emit Approval(_msgSender(), spender, allowanceAmount);
        }
        return result;
    }

    function _mint(address receipient, uint256 amount) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().mint(receipient, amount);
    }

    function _burn(uint256 amount) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().burn(amount);
    }

    function _burnFrom(address receipient, uint256 amount) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().burnFrom(receipient, amount);
    }

    function _decreaseAllowance(address spender, uint256 subtractedValue) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().decreaseAllowance(spender, subtractedValue);
    }

    function _increaseAllowance(address spender, uint256 addedValue) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().increaseAllowance(spender, addedValue);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().transferFrom(sender, recipient, amount);
    }

    function _approve(address spender, uint256 amount) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().approve(spender, amount);
    }

    function _transfer(address recipient, uint256 amount) private returns (bool) {
        _getStorageContract().prepareCall(_msgSender());
        return _getStorageContract().transfer(recipient, amount);
    }

    function domainName() public virtual override view returns (bytes memory) {
        return bytes(name());
    }

    function domainVersion() public virtual override view returns (bytes32) {
        return bytes32(uint256(uint160(address(_getImplementationContract()))));
    }
}