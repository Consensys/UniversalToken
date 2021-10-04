## `DVPHoldableLockable`

Facilitates the atomic settlement of ERC20 and ERC1400 Holdable Tokens.




### `constructor()` (public)

[DVP CONSTRUCTOR]



### `executeHolds(address token1, bytes32 token1HoldId, enum DVPHoldableLockable.Standard tokenStandard1, address token2, bytes32 token2HoldId, enum DVPHoldableLockable.Standard tokenStandard2, bytes32 preimage)` (public)

Execute holds where the hold recipients are already known
     @param token1 contract address of the first token
     @param token1HoldId 32 byte hold identified from the first token
     @param tokenStandard1 Standard enum indicating if the first token is HoldableERC20 or HoldableERC1400
     @param token2 contract address of the second token
     @param token2HoldId 32 byte hold identified from the second token
     @param tokenStandard2 Standard enum indicating if the second token is HoldableERC20 or HoldableERC1400
     @param preimage optional preimage of the SHA256 hash used to lock both the token holds. This can be a zero address if no lock hash was used.



### `executeHolds(address token1, bytes32 token1HoldId, enum DVPHoldableLockable.Standard tokenStandard1, address token2, bytes32 token2HoldId, enum DVPHoldableLockable.Standard tokenStandard2, bytes32 preimage, address token1Recipient, address token2Recipient)` (public)

Execute holds where the hold recipients are only known at execution.
     @param token1 contract address of the first token
     @param token1HoldId 32 byte hold identified from the first token
     @param tokenStandard1 Standard enum indicating if the first token is HoldableERC20 or HoldableERC1400
     @param token2 contract address of the second token
     @param token2HoldId 32 byte hold identified from the second token
     @param tokenStandard2 Standard enum indicating if the second token is HoldableERC20 or HoldableERC1400
     @param preimage optional preimage of the SHA256 hash used to lock both the token holds. This can be a zero address if no lock hash was used.
     @param token1Recipient address of the recipient of the first tokens.
     @param token2Recipient address of the recipient of the second tokens.



### `_executeHolds(address token1, bytes32 token1HoldId, enum DVPHoldableLockable.Standard tokenStandard1, address token2, bytes32 token2HoldId, enum DVPHoldableLockable.Standard tokenStandard2, bytes32 preimage, address token1Recipient, address token2Recipient)` (internal)



this is in a separate function to work around stack too deep problems

### `_executeERC20Hold(address token, bytes32 tokenHoldId, bytes32 preimage, address tokenRecipient)` (internal)





### `_executeERC1400Hold(address token, bytes32 tokenHoldId, bytes32 preimage)` (internal)






### `ExecuteHolds(address token1, bytes32 token1HoldId, address token2, bytes32 token2HoldId, bytes32 preimage, address token1Recipient, address token2Recipient)`





### `ExecutedHold(bytes32 holdId, bytes32 lockPreimage)`



Include token events so they can be parsed by Ethereum clients from the settlement transactions.

### `ExecutedHold(bytes32 holdId, bytes32 lockPreimage, address recipient)`





### `Transfer(address from, address to, uint256 tokens)`





### `TransferByPartition(bytes32 fromPartition, address operator, address from, address to, uint256 value, bytes data, bytes operatorData)`





### `CreateNote(address owner, bytes32 noteHash, bytes metadata)`





### `DestroyNote(address owner, bytes32 noteHash)`







### `Standard`











