pragma solidity ^0.8.0;

import {IERC20Storage} from "../../storage/IERC20Storage.sol";
import {IERC20Logic} from "./IERC20Logic.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IERC20Storage} from "../../storage/IERC20Storage.sol";
import {TransferData} from "../../../../extensions/ERC20/IERC20Extension.sol";

/**
* @dev Contract to be used with along with an ERC20ProxyBase and an ERC20Storage. This contract requires
* you to provide the address of the ERC20ProxyBase and the ERC20Storage contract to use. This contract
* will confirm the correct context by ensuring the caller of this contract is the proxy set,
* there is a valid storage contract and that the ERC20Storage address it points to accepts
* us as a writer
*
* This contract implements the core logic for an ERC20 token, storing the results in a
* corrasponding ERC20Storage contract.
*
*/
contract ERC20LogicBase is IERC20Logic {
    bytes32 constant ERC20_STORAGE_ADDRESS_DEFAULT = keccak256("erc20.core.storage.address");
    bytes32 constant ERC20_PROXY_ADDRESS = keccak256("erc20.core.proxy.address");
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    constructor(address proxy, address store) {
        _initalize(proxy, store);
    }

    function _initalize(address proxy, address store) internal {
        //Don't write if value is zero
        if (store != ZERO_ADDRESS) {
            StorageSlot.getAddressSlot(_getStorageLocation()).value = store;
        }
        
        if (proxy != ZERO_ADDRESS) {
            StorageSlot.getAddressSlot(ERC20_PROXY_ADDRESS).value = proxy;
        }
    }

    modifier confirmContext {
        require(_confirmContext(), "This function is being executed in the incorrect context");
        _;
    }

    function _getStorageLocation() internal virtual pure returns (bytes32) {
        return ERC20_STORAGE_ADDRESS_DEFAULT;
    }

    function _getStorageContract() internal virtual view returns (IERC20Storage) {
        return IERC20Storage(
            StorageSlot.getAddressSlot(_getStorageLocation()).value
        );
    }

    function _getProxyAddress() internal virtual view returns (address) {
        return StorageSlot.getAddressSlot(ERC20_PROXY_ADDRESS).value;
    }

    function _confirmContext() internal virtual view returns (bool) {
        return msg.sender == _getProxyAddress() && _getStorageContract().allowWriteFrom(address(this));
    }

    function _balanceOf(address account) internal virtual view returns (uint256) {
        return _getStorageContract().balanceOf(account);
    }

    function _setBalance(address owner, uint256 amount) internal virtual returns (bool) {
       return _getStorageContract().setBalance(owner, amount);
    }

    function _increaseBalance(address owner, uint256 amount) internal virtual returns (bool) {
        return _getStorageContract().increaseBalance(owner, amount);
    }

    function _allowance(address owner, address spender) internal virtual view returns (uint256) {
        return _getStorageContract().allowance(owner, spender);
    }

    function _increaseTotalSupply(uint256 amount) internal virtual returns (bool) {
        return _getStorageContract().increaseTotalSupply(amount);
    }

    function _decreaseTotalSupply(uint256 amount) internal virtual returns (bool) {
        return _getStorageContract().decreaseTotalSupply(amount);
    }

    function _setAllowance(address owner, address spender, uint256 amount) internal virtual returns (bool) {
        return _getStorageContract().setAllowance(owner, spender, amount);
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address caller, address recipient, uint256 amount) external override confirmContext returns (bool) {
        _transfer(caller, caller, recipient, amount);
        return true;
    }

    function customTransfer(TransferData memory data) external override confirmContext returns (bool) {
        _transfer(data);
        return true;
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
    function approve(address caller, address spender, uint256 amount) external override confirmContext returns (bool) {
        _approve(caller, caller, spender, amount);
        return true;
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
        address caller, 
        address sender,
        address recipient,
        uint256 amount
    ) external override confirmContext returns (bool) {
        _transfer(caller, sender, recipient, amount);

        uint256 currentAllowance = _allowance(sender, caller);
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        unchecked {
            _approve(caller, sender, caller, currentAllowance - amount);
        }

        return true;
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
    function increaseAllowance(address caller, address spender, uint256 addedValue) public override confirmContext returns (bool) {
        _approve(caller, caller, spender, _allowance(caller, spender) + addedValue);
        return true;
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
    function decreaseAllowance(address caller, address spender, uint256 subtractedValue) public override confirmContext returns (bool) {
        uint256 currentAllowance = _allowance(caller, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(caller, caller, spender, currentAllowance - subtractedValue);

        return true;
    }

    function mint(address caller, address recipient, uint256 amount) external override returns (bool) {
        _mint(caller, recipient, amount);

        return true;
    }

    function burn(address caller, address recipient, uint256 amount) external override returns (bool) {
        _burn(caller, recipient, amount);

        return true;
    }

    function burnFrom(address caller, address account, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowance(account, caller);
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(caller, account, caller, currentAllowance - amount);
        }
        _burn(caller, account, amount);

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address caller,
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        TransferData memory data = TransferData(
            _getProxyAddress(),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            sender,
            recipient,
            amount,
            "",
            ""
        );

        _transfer(data);
    }

        /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(TransferData memory data) internal virtual {
        require(data.from != address(0), "ERC20: transfer from the zero address");
        require(data.to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(data);

        uint256 senderBalance = _balanceOf(data.from);
        require(senderBalance >= data.value, "ERC20: transfer amount exceeds balance");
        require(_setBalance(data.from, senderBalance - data.value), "ERC20: Set balance of sender failed");
        require(_increaseBalance(data.to, data.value), "ERC20: Increase balance of recipient failed");

        _afterTokenTransfer(data);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address caller, address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        TransferData memory data = TransferData(
            _getProxyAddress(),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            address(0),
            account,
            amount,
            "",
            ""
        );

        _beforeTokenTransfer(data);
        
        require(_increaseTotalSupply(amount), "ERC20: increase total supply failed");
        require(_increaseBalance(account, amount), "ERC20: increase balance failed");

        _afterTokenTransfer(data);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address caller, address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        TransferData memory data = TransferData(
            _getProxyAddress(),
            msg.data,
            0x00000000000000000000000000000000,
            caller,
            account,
            address(0),
            amount,
            "",
            ""
        );

        _beforeTokenTransfer(data);

        uint256 accountBalance = _getStorageContract().balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        require(_setBalance(account, accountBalance - amount), "ERC20: Set balance of account failed");
        require(_decreaseTotalSupply(amount), "ERC20: Decrease of total supply failed");

        _afterTokenTransfer(data);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address caller,
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        require(_setAllowance(owner, spender, amount), "ERC20: approve write failed");
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(TransferData memory data) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(TransferData memory data) internal virtual {}
}