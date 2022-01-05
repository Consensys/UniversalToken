pragma solidity ^0.8.0;

import {IERC20Storage} from "./IERC20Storage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC20Storage is IERC20Storage, AccessControl {
    address private _currentWriter;
    address private _admin;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentWriter = _admin = msg.sender;
    }

    modifier onlyWriter {
        require(_currentWriter == msg.sender, "Only writers can execute this function");
        _;
    }

    modifier onlyAdmin {
        require(_admin == msg.sender, "Only writers can execute this function");
        _;
    }

    function changeCurrentWriter(address newWriter) external override onlyAdmin {
        _currentWriter = newWriter;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() external override view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external override view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external override view returns (uint8) {
        return 18;
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external override view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external override view returns (uint256) {
        return _allowances[owner][spender];
    }

    function setAllowance(address owner, address spender, uint256 amount) external override onlyWriter returns (bool) {
        _allowances[owner][spender] = amount;
        return true;
    }

    function setBalance(address owner, uint256 amount) external override onlyWriter returns (bool) {
        _balances[owner] = amount;
        return true;
    }

    function decreaseTotalSupply(uint256 amount) external override onlyWriter returns (bool) {
        _totalSupply -= amount;
        return true;
    }

    function increaseTotalSupply(uint256 amount) external override onlyWriter returns (bool) {
        _totalSupply += amount;
        return true;
    }

    function setTotalSupply(uint256 amount) external override onlyWriter returns (bool) {
        _totalSupply = amount;
        return true;
    }

    function increaseBalance(address owner, uint256 amount) external override onlyWriter returns (bool) {
        _balances[owner] += amount;
        return true;
    }

    function allowWriteFrom(address source) external override view returns (bool) {
        return _currentWriter == source;
    }
}