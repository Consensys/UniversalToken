## `FundIssuer`



Fund issuance contract.
Intended usage:
The purpose of the contract is to perform a fund issuance.


### `onlyTokenController(address tokenAddress)`



Modifier to verify if sender is a token controller.

### `onlyPriceOracle(address assetAddress)`



Modifier to verify if sender is a price oracle.


### `constructor()` (public)

[DVP CONSTRUCTOR]


Initialize Fund issuance contract + register
the contract implementation in ERC1820Registry.

### `canReceive(bytes, bytes32, address, address, address, uint256, bytes data, bytes operatorData) → bool` (external)

[ERC1400TokensRecipient INTERFACE (1/2)]


Indicate whether or not the fund issuance contract can receive the tokens or not. [USED FOR ERC1400 TOKENS ONLY]


### `tokensReceived(bytes, bytes32 partition, address, address from, address to, uint256 value, bytes data, bytes operatorData)` (external)

[ERC1400TokensRecipient INTERFACE (2/2)]


Hook function executed when tokens are sent to the fund issuance contract. [USED FOR ERC1400 TOKENS ONLY]


### `setAssetRules(address assetAddress, bytes32 assetClass, uint256 firstStartTime, uint256 subscriptionPeriodLength, uint256 valuationPeriodLength, uint256 paymentPeriodLength, enum FundIssuer.Payment paymentType, address paymentAddress, bytes32 paymentPartition, address fundAddress, bool subscriptionsOpened)` (external)

/**


Start a new subscription for a given asset in the fund issuance smart contract.


### `setAssetValueRules(address assetAddress, bytes32 assetClass, enum FundIssuer.AssetValue assetValueType, uint256 assetValue, uint256 reverseAssetValue)` (external)

*


Set asset value rules for a given asset.


### `_startNewCycle(address assetAddress, bytes32 assetClass) → uint256` (internal)

*


Start a new subscription for a given asset in the fund issuance smart contract.


### `_getNextStartTime(uint256 previousStartTime, uint256 subscriptionPeriod) → uint256` (internal)

*


Returns time of next cycle start.


### `subscribe(address assetAddress, bytes32 assetClass, uint256 orderValue, uint256 orderAmount, enum FundIssuer.OrderType orderType, bool executePaymentAtSubscription) → uint256` (external)

*


Subscribe for a given asset, by creating an order.


### `_subscribe(address investor, address assetAddress, bytes32 assetClass, bytes orderData, bool executePaymentAtSubscription, bytes erc1400TokenData) → uint256` (internal)




Subscribe for a given asset, by creating an order.


### `cancelOrder(uint256 orderIndex)` (external)




Cancel an order.


### `rejectOrder(uint256 orderIndex, bool rejected)` (external)




Reject an order.


### `valuate(uint256 cycleIndex, uint256 assetValue, uint256 reverseAssetValue)` (external)




Set assetValue for a given asset.


### `executePaymentAsInvestor(uint256 orderIndex)` (external)




Execute payment for a given order.


### `executePaymentAsController(uint256 orderIndex, bool bypassPayment)` (external)




Set payment as executed for a given order.


### `batchExecutePaymentsAsController(uint256[] orderIndexes, bool bypassPayment)` (external)




Set payments as executed for a batch of given orders.


### `_executePayment(uint256 orderIndex, bytes erc1400TokenData, bool bypassPayment)` (internal)




Pay for a given order.


### `_getOrderAmountAndValue(uint256 orderIndex) → uint256, uint256` (internal)




Retrieve order amount and order value calculated based on cycle valuation.


### `_releasePayment(uint256 orderIndex, address recipient)` (internal)




Release payment for a given order.


### `settleOrder(uint256 orderIndex)` (internal)




Settle a given order.


### `batchSettleOrders(uint256[] orderIndexes)` (external)




Settle a batch of given orders.


### `_settleOrder(uint256 orderIndex)` (internal)




Settle a given order.


### `finalizeCycle(uint256 cycleIndex)` (external)




Finalize a given cycle.


### `getTotalSettledForCycle(uint256 cycleIndex) → uint256, uint256, bool` (external)




Retrieve sum of paid/unpaid settled orders for a given cycle.



### `_getTotalSettledForCycle(uint256 cycleIndex) → uint256, uint256, bool` (internal)




Retrieve sum of paid/unpaid settled orders for a given cycle.



### `getCycleState(uint256 cycleIndex) → enum FundIssuer.CycleState` (external)




Retrieve the current state of the cycle.



### `_getCycleState(uint256 cycleIndex) → enum FundIssuer.CycleState` (internal)




Retrieve the current state of the cycle.



### `_tokenController(address sender, address assetAddress) → bool` (internal)




Check if the sender is a token controller.



### `_canReceive(bytes data, bytes operatorData) → bool` (internal)




Indicate whether or not the fund issuance contract can receive the tokens.

By convention, the 32 first bytes of a token transfer to the fund issuance smart contract contain a flag.

 - When tokens are transferred to fund issuance contract to create a new order, the 'data' field starts with the
 following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
 In this case the data structure is the the following:
 <transferFlag (32 bytes)><asset address (32 bytes)><asset class (32 bytes)><order data (3 * 32 bytes)>

 - When tokens are transferred to fund issuance contract to pay for an existing order, the 'data' field starts with the
 following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
 In this case the data structure is the the following:
 <transferFlag (32 bytes)><order index (32 bytes)>

If the 'data' doesn't start with one of those flags, the fund issuance contract won't accept the token transfer.



### `_getTransferFlag(bytes data) → bytes32 flag` (internal)




Retrieve the transfer flag from the 'data' field.

By convention, the 32 first bytes of a token transfer to the fund issuance smart contract contain a flag.
 - When tokens are transferred to fund issuance contract to create a new order, the 'data' field starts with the
 following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
 - When tokens are transferred to fund issuance contract to pay for an existing order, the 'data' field starts with the
 following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd



### `_getAssetAddress(bytes data) → address assetAddress` (internal)


By convention, when tokens are transferred to fund issuance contract to create a new order, the 'data' of a token transfer has the following structure:
 <transferFlag (32 bytes)><asset address (32 bytes)><asset class (32 bytes)><order data (3 * 32 bytes)>

The first 32 bytes are the flag 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

The next 32 bytes contain the order index.

Example input for asset address '0xb5747835141b46f7C472393B31F8F5A57F74A44f',
asset class '37252', order type 'Value', and value 12000
0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000b5747835141b46f7C472393B31F8F5A57F74A44f
000000000000000000000000000000000000000000000000000000000037252000000000000000000000000000000000000000000000000000000000000001
000000000000000000000000000000000000000000000000000000000002ee0000000000000000000000000000000000000000000000000000000000000000

/



### `_getAssetClass(bytes data) → bytes32 assetClass` (internal)





### `_getOrderData(bytes data) → bytes orderData` (internal)





### `_getOrderIndex(bytes data) → uint256 orderIndex` (internal)




Retrieve the order index from the 'data' field.



### `tokenControllers(address tokenAddress) → address[]` (external)




Get the list of token controllers for a given token.


### `setTokenControllers(address tokenAddress, address[] operators)` (external)




Set list of token controllers for a given token.


### `_setTokenControllers(address tokenAddress, address[] operators)` (internal)




Set list of token controllers for a given token.


### `priceOracles(address tokenAddress) → address[]` (external)




Get the list of price oracles for a given token.


### `setPriceOracles(address tokenAddress, address[] oracles)` (external)




Set list of price oracles for a given token.


### `_setPriceOracles(address tokenAddress, address[] oracles)` (internal)




Set list of price oracles for a given token.


### `_checkPriceOracle(address tokenAddress, address oracle) → bool` (internal)




Check if address is oracle of a given token.


### `getAssetRules(address assetAddress, bytes32 assetClass) → uint256, uint256, uint256, uint256, enum FundIssuer.Payment, address, bytes32, address, bool` (external)




Get asset rules.


### `getAssetValueRules(address assetAddress, bytes32 assetClass) → enum FundIssuer.AssetValue, uint256, uint256` (external)




Get the cycle asset value rules.


### `getNbCycles() → uint256` (external)




Get total number of cycles in the contract.


### `getLastCycleIndex(address assetAddress, bytes32 assetClass) → uint256` (external)




Get the index of the last cycle created for a given asset class.


### `getCycle(uint256 index) → address, bytes32, uint256, uint256, uint256, uint256, enum FundIssuer.Payment, address, bytes32, bool` (external)




Get the cycle.


### `getCycleAssetValue(uint256 index) → enum FundIssuer.AssetValue, uint256, uint256` (external)




Get the cycle asset value.


### `getNbOrders() → uint256` (external)




Get total number of orders in the contract.


### `getOrder(uint256 index) → uint256, address, uint256, uint256, enum FundIssuer.OrderType, enum FundIssuer.OrderState` (external)




Retrieve an order.


### `getOrderAmountAndValue(uint256 orderIndex) → uint256, uint256` (external)




Retrieve order amount and order value calculated based on cycle valuation.


### `getCycleOrders(uint256 index) → uint256[]` (external)




Get list of cycle orders.


### `getInvestorOrders(address investor) → uint256[]` (external)




Get list of investor orders.




### `AssetRules`


bool defined


uint256 firstStartTime


uint256 subscriptionPeriodLength


uint256 valuationPeriodLength


uint256 paymentPeriodLength


enum FundIssuer.AssetValue assetValueType


uint256 assetValue


uint256 reverseAssetValue


enum FundIssuer.Payment paymentType


address paymentAddress


bytes32 paymentPartition


address fundAddress


bool subscriptionsOpened


### `Cycle`


address assetAddress


bytes32 assetClass


uint256 startTime


uint256 subscriptionPeriodLength


uint256 valuationPeriodLength


uint256 paymentPeriodLength


enum FundIssuer.AssetValue assetValueType


uint256 assetValue


uint256 reverseAssetValue


enum FundIssuer.Payment paymentType


address paymentAddress


bytes32 paymentPartition


address fundAddress


bool finalized


### `Order`


uint256 cycleIndex


address investor


uint256 value


uint256 amount


enum FundIssuer.OrderType orderType


enum FundIssuer.OrderState state



### `CycleState`




















### `OrderState`























### `OrderType`











### `Payment`














### `AssetValue`








