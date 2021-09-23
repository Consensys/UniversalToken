pragma solidity ^0.8.0;

interface IERC20Storage {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);

    function changeCurrentWriter(address newWriter) external;

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

        /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    function setAllowance(address owner, address spender, uint256 amount) external returns (bool);

    function setBalance(address owner, uint256 amount) external returns (bool);

    function decreaseTotalSupply(uint256 amount) external returns (bool);

    function increaseTotalSupply(uint256 amount) external returns (bool);

    function setTotalSupply(uint256 amount) external returns (bool);

    function increaseBalance(address owner, uint256 amount) external returns (bool);

    function allowWriteFrom(address source) external view returns (bool);
}