## `ERC1400TokensValidator`





### `onlyTokenController(address token)`



Modifier to verify if sender is a token controller.

### `onlyPauser(address token)`



Modifier to verify if sender is a pauser.

### `onlyCertificateSigner(address token)`



Modifier to verify if sender is a pauser.

### `onlyAllowlistAdmin(address token)`



Modifier to verify if sender is an allowlist admin.

### `onlyBlocklistAdmin(address token)`



Modifier to verify if sender is a blocklist admin.


### `retrieveTokenSetup(address token) → enum ERC1400TokensValidator.CertificateValidation, bool, bool, bool, bool, address[]` (external)



Get the list of token controllers for a given token.


### `registerTokenSetup(address token, enum ERC1400TokensValidator.CertificateValidation certificateActivated, bool allowlistActivated, bool blocklistActivated, bool granularityByPartitionActivated, bool holdsActivated, address[] operators)` (external)



Register token setup.

### `_setTokenControllers(address token, address[] operators)` (internal)



Set list of token controllers for a given token.


### `canValidate(struct IERC1400TokensValidator.ValidateData data) → bool` (external)



Verify if a token transfer can be executed or not, on the validator's perspective.


### `tokensToValidate(bytes payload, bytes32 partition, address operator, address from, address to, uint256 value, bytes data, bytes operatorData)` (external)



Function called by the token contract before executing a transfer.


### `_canValidateCertificateToken(address token, bytes payload, address operator, bytes certificate) → bool, enum ERC1400TokensValidator.CertificateValidation, bytes32` (internal)



Verify if a token transfer can be executed or not, on the validator's perspective.


### `_canValidateAllowlistAndBlocklistToken(address token, bytes payload, address from, address to) → bool` (internal)



Verify if a token transfer can be executed or not, on the validator's perspective.


### `_canValidateGranularToken(address token, bytes32 partition, uint256 value) → bool` (internal)



Verify if a token transfer can be executed or not, on the validator's perspective.


### `_canValidateHoldableToken(address token, bytes32 partition, address operator, address from, address to, uint256 value) → bool` (internal)



Verify if a token transfer can be executed or not, on the validator's perspective.


### `granularityByPartition(address token, bytes32 partition) → uint256` (external)



Get granularity for a given partition.


### `setGranularityByPartition(address token, bytes32 partition, uint256 granularity)` (external)



Set partition granularity

### `preHoldFor(address token, bytes32 holdId, address recipient, address notary, bytes32 partition, uint256 value, uint256 timeToExpiration, bytes32 secretHash, bytes certificate) → bool` (external)



Create a new token pre-hold.

### `preHoldForWithExpirationDate(address token, bytes32 holdId, address recipient, address notary, bytes32 partition, uint256 value, uint256 expiration, bytes32 secretHash, bytes certificate) → bool` (external)



Create a new token pre-hold with expiration date.

### `hold(address token, bytes32 holdId, address recipient, address notary, bytes32 partition, uint256 value, uint256 timeToExpiration, bytes32 secretHash, bytes certificate) → bool` (external)



Create a new token hold.

### `holdWithExpirationDate(address token, bytes32 holdId, address recipient, address notary, bytes32 partition, uint256 value, uint256 expiration, bytes32 secretHash, bytes certificate) → bool` (external)



Create a new token hold with expiration date.

### `holdFrom(address token, bytes32 holdId, address sender, address recipient, address notary, bytes32 partition, uint256 value, uint256 timeToExpiration, bytes32 secretHash, bytes certificate) → bool` (external)



Create a new token hold on behalf of the token holder.

### `holdFromWithExpirationDate(address token, bytes32 holdId, address sender, address recipient, address notary, bytes32 partition, uint256 value, uint256 expiration, bytes32 secretHash, bytes certificate) → bool` (external)



Create a new token hold with expiration date on behalf of the token holder.

### `_createHold(address token, bytes32 holdId, address sender, address recipient, address notary, bytes32 partition, uint256 value, uint256 expiration, bytes32 secretHash, bytes certificate) → bool` (internal)



Create a new token hold.

### `releaseHold(address token, bytes32 holdId) → bool` (external)



Release token hold.

### `_releaseHold(address token, bytes32 holdId) → bool` (internal)



Release token hold.

### `renewHold(address token, bytes32 holdId, uint256 timeToExpiration, bytes certificate) → bool` (external)



Renew hold.

### `renewHoldWithExpirationDate(address token, bytes32 holdId, uint256 expiration, bytes certificate) → bool` (external)



Renew hold with expiration time.

### `_renewHold(address token, bytes32 holdId, uint256 expiration, bytes certificate) → bool` (internal)



Renew hold.

### `executeHold(address token, bytes32 holdId, uint256 value, bytes32 secret) → bool` (external)



Execute hold.

### `executeHoldAndKeepOpen(address token, bytes32 holdId, uint256 value, bytes32 secret) → bool` (external)



Execute hold and keep open.

### `_executeHold(address token, bytes32 holdId, address operator, uint256 value, bytes32 secret, bool keepOpenIfHoldHasBalance) → bool` (internal)



Execute hold.

### `_setHoldToExecuted(address token, struct ERC1400TokensValidator.Hold executableHold, bytes32 holdId, uint256 value, uint256 heldBalanceDecrease, bytes32 secret)` (internal)



Set hold to executed.

### `_setHoldToExecutedAndKeptOpen(address token, struct ERC1400TokensValidator.Hold executableHold, bytes32 holdId, uint256 value, uint256 heldBalanceDecrease, bytes32 secret)` (internal)



Set hold to executed and kept open.

### `_checkSecret(struct ERC1400TokensValidator.Hold executableHold, bytes32 secret) → bool` (internal)



Check secret.

### `_computeExpiration(uint256 timeToExpiration) → uint256` (internal)



Compute expiration time.

### `_isExpired(uint256 expiration) → bool` (internal)



Check is expiration date is past.

### `_retrieveHoldHashId(address token, bytes32 partition, address notary, address sender, address recipient, uint256 value) → bytes32, bytes32` (internal)



Retrieve hold hash, and ID for given parameters

### `_holdCanBeExecuted(struct ERC1400TokensValidator.Hold executableHold, uint256 value) → bool` (internal)



Check if hold can be executed

### `_holdCanBeExecutedAsSecretHolder(struct ERC1400TokensValidator.Hold executableHold, uint256 value, bytes32 secret) → bool` (internal)



Check if hold can be executed as secret holder

### `_holdCanBeExecutedAsNotary(struct ERC1400TokensValidator.Hold executableHold, address operator, uint256 value) → bool` (internal)



Check if hold can be executed as notary

### `retrieveHoldData(address token, bytes32 holdId) → bytes32 partition, address sender, address recipient, address notary, uint256 value, uint256 expiration, bytes32 secretHash, bytes32 secret, enum HoldStatusCode status` (external)



Retrieve hold data.

### `totalSupplyOnHold(address token) → uint256` (external)



Total supply on hold.

### `totalSupplyOnHoldByPartition(address token, bytes32 partition) → uint256` (external)



Total supply on hold for a specific partition.

### `balanceOnHold(address token, address account) → uint256` (external)



Get balance on hold of a tokenholder.

### `balanceOnHoldByPartition(address token, bytes32 partition, address account) → uint256` (external)



Get balance on hold of a tokenholder for a specific partition.

### `spendableBalanceOf(address token, address account) → uint256` (external)



Get spendable balance of a tokenholder.

### `spendableBalanceOfByPartition(address token, bytes32 partition, address account) → uint256` (external)



Get spendable balance of a tokenholder for a specific partition.

### `_spendableBalanceOf(address token, address account) → uint256` (internal)



Get spendable balance of a tokenholder.

### `_spendableBalanceOfByPartition(address token, bytes32 partition, address account) → uint256` (internal)



Get spendable balance of a tokenholder for a specific partition.

### `_canHoldOrCanPreHold(address token, address operator, address sender, bytes certificate) → bool` (internal)



Check if hold (or pre-hold) can be created.


### `_functionSupportsCertificateValidation(bytes payload) → bool` (internal)



Check if validator is activated for the function called in the smart contract.


### `_useCertificateIfActivated(address token, enum ERC1400TokensValidator.CertificateValidation certificateControl, address msgSender, bytes32 salt)` (internal)



Use certificate, if validated.


### `_getFunctionSig(bytes payload) → bytes4` (internal)



Extract function signature from payload.


### `_isMultiple(uint256 granularity, uint256 value) → bool` (internal)



Check if 'value' is multiple of 'granularity'.


### `usedCertificateNonce(address token, address sender) → uint256` (external)



Get state of certificate (used or not).


### `_checkNonceBasedCertificate(address token, address msgSender, bytes payloadWithCertificate, bytes certificate) → bool` (internal)



Checks if a nonce-based certificate is correct


### `usedCertificateSalt(address token, bytes32 salt) → bool` (external)



Get state of certificate (used or not).


### `_checkSaltBasedCertificate(address token, address msgSender, bytes payloadWithCertificate, bytes certificate) → bool, bytes32` (internal)



Checks if a salt-based certificate is correct



### `HoldCreated(address token, bytes32 holdId, bytes32 partition, address sender, address recipient, address notary, uint256 value, uint256 expiration, bytes32 secretHash)`





### `HoldReleased(address token, bytes32 holdId, address notary, enum HoldStatusCode status)`





### `HoldRenewed(address token, bytes32 holdId, address notary, uint256 oldExpiration, uint256 newExpiration)`





### `HoldExecuted(address token, bytes32 holdId, address notary, uint256 heldValue, uint256 transferredValue, bytes32 secret)`





### `HoldExecutedAndKeptOpen(address token, bytes32 holdId, address notary, uint256 heldValue, uint256 transferredValue, bytes32 secret)`






### `Hold`


bytes32 partition


address sender


address recipient


address notary


uint256 value


uint256 expiration


bytes32 secretHash


bytes32 secret


enum HoldStatusCode status



### `CertificateValidation`











