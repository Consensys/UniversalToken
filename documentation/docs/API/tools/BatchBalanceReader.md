## `BatchBalanceReader`



Proxy contract to read multiple ERC1400/ERC20 token balances in a single contract call.


### `balancesOfByPartition(address[] tokenHolders, address[] tokenAddresses, bytes32[] partitions) → uint256[]` (external)



Get a batch of ERC1400 token balances.


### `balancesOf(address[] tokenHolders, address[] tokenAddresses) → uint256[]` (external)



Get a batch of ERC20 token balances.


### `totalSuppliesByPartition(bytes32[] partitions, address[] tokenAddresses) → uint256[]` (external)



Get a batch of ERC1400 token total supplies by partitions.


### `totalSupplies(address[] tokenAddresses) → uint256[]` (external)



Get a batch of ERC20 token total supplies.





