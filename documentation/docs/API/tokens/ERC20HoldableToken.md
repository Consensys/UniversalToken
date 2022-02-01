## `ERC20HoldableToken`

A hold is like an approve where held tokens can not be spent by the token holder until after an hold expiration period.
    The hold can be executed by a notary, which can be the recipient of the tokens, a third party or a smart contract.
    The notary can execute the hold before or after the expiration period.
    Additionally, a hash lock at be applied which requires the notary of the hold to present the hash preimage to execute the hold.
    Held tokens can be released by the notary at any time or by the token holder after the expiration period.
    A recipient does not have to get set at the time of the hold, which means it will have to be specified when the hold is executed.



### `isHeld(bytes32 holdId)`






### `constructor(string name, string symbol, uint8 decimals)` (public)





### `generateHoldId(address recipient, address notary, uint256 amount, uint256 expirationDateTime, bytes32 lockHash) → bytes32 holdId` (external)





### `retrieveHoldHashId(address notary, address sender, address recipient, uint256 value) → bytes32, bytes32` (public)



Retrieve hold hash, and ID for given parameters

### `hold(bytes32 holdId, address recipient, address notary, uint256 amount, uint256 expirationDateTime, bytes32 lockHash) → bool` (public)

Called by the sender to hold some tokens for a recipient that the sender can not release back to themself until after the expiration date.
     @param recipient optional account the tokens will be transferred to on execution. If a zero address, the recipient must be specified on execution of the hold.
     @param notary account that can execute the hold. Typically the recipient but can be a third party or a smart contact.
     @param amount of tokens to be transferred to the recipient on execution. Must be a non zero amount.
     @param expirationDateTime UNIX epoch seconds the held amount can be released back to the sender by the sender. Past dates are allowed.
     @param lockHash optional keccak256 hash of a lock preimage. An empty hash will not enforce the hash lock when the hold is executed.
     @return holdId a unique identifier for the hold.



### `retrieveHoldData(bytes32 holdId) → struct ERC20HoldData` (external)





### `executeHold(bytes32 holdId)` (public)

Called by the notary to transfer the held tokens to the set at the hold recipient if there is no hash lock.
     @param holdId a unique identifier for the hold.



### `executeHold(bytes32 holdId, bytes32 lockPreimage)` (public)

Called by the notary to transfer the held tokens to the recipient that was set at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a sha256 hash



### `executeHold(bytes32 holdId, bytes32 lockPreimage, address recipient)` (public)

Called by the notary to transfer the held tokens to the recipient if no recipient was specified at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a keccak256 hash
     @param recipient the account the tokens will be transferred to on execution.



### `_executeHold(bytes32 holdId, bytes32 lockPreimage, address recipient)` (internal)





### `releaseHold(bytes32 holdId)` (public)

Called by the notary at any time or the sender after the expiration date to release the held tokens back to the sender.
     @param holdId a unique identifier for the hold.



### `balanceOf(address account) → uint256` (public)

/**
     @notice Amount of tokens owned by an account that are available for transfer. That is, the gross balance less any held tokens.
     @param account owner of the tokensß
/



### `balanceOnHold(address account) → uint256` (public)

*
     @notice Amount of tokens owned by an account that are held pending execution or release.
     @param account owner of the tokens
/



### `spendableBalanceOf(address account) → uint256` (public)

*
     @notice Total amount of tokens owned by an account including all the held tokens pending execution or release.
     @param account owner of the tokens
/



### `holdStatus(bytes32 holdId) → enum HoldStatusCode` (public)

*
     @param holdId a unique identifier for the hold.
     @return hold status code.
/



### `transfer(address recipient, uint256 amount) → bool` (public)

*
     @notice ERC20 transfer that checks on hold tokens can not be transferred.
/



### `transferFrom(address sender, address recipient, uint256 amount) → bool` (public)

*
     @notice ERC20 transferFrom that checks on hold tokens can not be transferred.
/



### `approve(address spender, uint256 amount) → bool` (public)

*
     @notice ERC20 approve that checks on hold tokens can not be approved for spending by another account.
/



### `burn(uint256 amount)` (public)

*
     @notice ERC20 burn that checks on hold tokens can not be burnt.
/



### `burnFrom(address account, uint256 amount)` (public)

*
     @notice ERC20 burnFrom that checks on hold tokens can not be burnt.
/






