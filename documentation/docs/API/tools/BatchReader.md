## `BatchReader`



Proxy contract to read multiple information from the smart contract in a single contract call.


### `batchTokenSuppliesInfos(address[] tokens) → uint256[], uint256[], bytes32[], uint256[], uint256[], bytes32[]` (external)



Get batch of token supplies.


### `batchTokenRolesInfos(address[] tokens) → address[], uint256[], address[], uint256[], address[]` (external)



Get batch of token roles.


### `batchControllers(address[] tokens) → uint256[], address[]` (public)



Get batch of token controllers.


### `batchExtensionControllers(address[] tokens) → uint256[], address[]` (public)



Get batch of token extension controllers.


### `batchTokenExtensionSetup(address[] tokens) → address[], enum IExtensionTypes.CertificateValidation[], bool[], bool[], bool[], bool[]` (external)



Get batch of token extension setup.


### `batchTokenExtensionSetup1(address[] tokens) → address[], enum IExtensionTypes.CertificateValidation[], bool[], bool[]` (public)



Get batch of token extension setup (part 1).


### `batchTokenExtensionSetup2(address[] tokens) → bool[], bool[]` (public)



Get batch of token extension setup (part 2).


### `batchERC1400Balances(address[] tokens, address[] tokenHolders) → uint256[], uint256[], uint256[], bytes32[], uint256[], uint256[]` (external)



Get batch of ERC1400 balances.


### `batchERC20Balances(address[] tokens, address[] tokenHolders) → uint256[], uint256[]` (external)



Get batch of ERC20 balances.


### `batchEthBalance(address[] tokenHolders) → uint256[]` (public)



Get batch of ETH balances.


### `batchBalanceOf(address[] tokens, address[] tokenHolders) → uint256[]` (public)



Get batch of token balances.


### `batchBalanceOfByPartition(address[] tokens, address[] tokenHolders) → uint256[], bytes32[], uint256[]` (public)



Get batch of partition balances.


### `batchSpendableBalanceOfByPartition(address[] tokens, address[] tokenHolders) → uint256[], bytes32[], uint256[]` (public)



Get batch of spendable partition balances.


### `batchTotalPartitions(address[] tokens) → uint256[], bytes32[], uint256[]` (public)



Get batch of token partitions.


### `batchDefaultPartitions(address[] tokens) → uint256[], bytes32[]` (public)



Get batch of token default partitions.


### `batchValidations(address[] tokens, address[] tokenHolders) → bool[], bool[]` (public)



Get batch of validation status.


### `batchAllowlisted(address[] tokens, address[] tokenHolders) → bool[]` (public)



Get batch of allowlisted status.


### `batchBlocklisted(address[] tokens, address[] tokenHolders) → bool[]` (public)



Get batch of blocklisted status.





