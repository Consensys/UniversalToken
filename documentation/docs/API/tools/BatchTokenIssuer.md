## `BatchTokenIssuer`



Proxy contract to issue multiple ERC1400/ERC20 tokens in a single transaction.

### `onlyTokenMinter(address token)`



Modifier to verify if sender is a token minter.


### `batchIssueByPartition(address token, bytes32[] partitions, address[] tokenHolders, uint256[] values) → uint256[]` (external)



Issue tokens for multiple addresses.





