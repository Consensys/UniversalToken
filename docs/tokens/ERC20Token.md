## `ERC20Token`






### `constructor(string name, string symbol, uint8 __decimals)` (public)





### `decimals() → uint8` (public)



Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5,05` (`505 / 10 ** 2`).

Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the value {ERC20} uses, unless this function is
overridden;

NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}.

### `mint(address to, uint256 value) → bool` (public)



Function to mint tokens


### `_beforeTokenTransfer(address from, address to, uint256 amount)` (internal)





### `domainName() → string` (public)





### `domainVersion() → string` (public)








