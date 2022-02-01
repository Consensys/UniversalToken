## `IERC20HoldableToken`



like approve except the tokens can't be spent by the sender while they are on hold.


### `hold(bytes32 holdId, address recipient, address notary, uint256 amount, uint256 expirationDateTime, bytes32 lockHash) → bool` (external)

Called by the sender to hold some tokens for a recipient that the sender can not release back to themself until after the expiration date.
     @param recipient optional account the tokens will be transferred to on execution. If a zero address, the recipient must be specified on execution of the hold.
     @param notary account that can execute the hold. Typically the recipient but can be a third party or a smart contact.
     @param amount of tokens to be transferred to the recipient on execution. Must be a non zero amount.
     @param expirationDateTime UNIX epoch seconds the held amount can be released back to the sender by the sender. Past dates are allowed.
     @param lockHash optional keccak256 hash of a lock preimage. An empty hash will not enforce the hash lock when the hold is executed.
     @return bool Whether the call was successful or not.



### `retrieveHoldData(bytes32 holdId) → struct ERC20HoldData` (external)





### `executeHold(bytes32 holdId)` (external)

Called by the notary to transfer the held tokens to the set at the hold recipient if there is no hash lock.
     @param holdId a unique identifier for the hold.



### `executeHold(bytes32 holdId, bytes32 lockPreimage)` (external)

Called by the notary to transfer the held tokens to the recipient that was set at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a keccak256 hash



### `executeHold(bytes32 holdId, bytes32 lockPreimage, address recipient)` (external)

Called by the notary to transfer the held tokens to the recipient if no recipient was specified at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a keccak256 hash
     @param recipient the account the tokens will be transferred to on execution.



### `releaseHold(bytes32 holdId)` (external)

Called by the notary at any time or the sender after the expiration date to release the held tokens back to the sender.
     @param holdId a unique identifier for the hold.



### `balanceOnHold(address account) → uint256` (external)

Amount of tokens owned by an account that are held pending execution or release.
     @param account owner of the tokens



### `spendableBalanceOf(address account) → uint256` (external)

Total amount of tokens owned by an account including all the held tokens pending execution or release.
     @param account owner of the tokens



### `totalSupplyOnHold() → uint256` (external)





### `holdStatus(bytes32 holdId) → enum HoldStatusCode` (external)






### `NewHold(bytes32 holdId, address recipient, address notary, uint256 amount, uint256 expirationDateTime, bytes32 lockHash)`





### `ExecutedHold(bytes32 holdId, bytes32 lockPreimage, address recipient)`





### `ReleaseHold(bytes32 holdId, address sender)`







