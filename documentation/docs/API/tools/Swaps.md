## `Swaps`



Delivery-Vs-Payment contract for investor-to-investor token trades.
Intended usage:
The purpose of the contract is to allow secure token transfers/exchanges between 2 stakeholders (called holder1 and holder2).
From now on, an operation in the Swaps smart contract (transfer/exchange) is called a trade.
Depending on the type of trade, one/multiple token transfers will be executed.

The simplified workflow is the following:
1) A trade request is created in the Swaps smart contract, it specifies:
 - The token holder(s) involved in the trade
 - The trade executer (optional)
 - An expiration date
 - Details on the first token (address, requested amount, standard)
 - Details on the second token (address, requested amount, standard)
 - Whether the tokens need to be escrowed in the Swaps contract or not
 - The current status of the trade (pending / executed / forced / cancelled)
2) The trade is accepted by both token holders
3) [OPTIONAL] The trade is approved by token controllers (only if requested by tokens controllers)
4) The trade is executed (either by the executer in case the executer is specified, or by anyone)

STANDARD-AGNOSTIC:
The Swaps smart contract is standard-agnostic, it supports ETH, ERC20, ERC721, ERC1400.
The advantage of using an ERC1400 token is to leverages its hook property, thus requiring ONE single
transaction (operatorTransferByPartition()) to send tokens to the Swaps smart contract instead of TWO
with the ERC20 token standard (approve() + transferFrom()).

OFF-CHAIN PAYMENT:
The contract can be used as escrow contract while waiting for an off-chain payment.
Once payment is received off-chain, the token sender realeases the tokens escrowed in
the Swaps contract to deliver them to the recipient.

ESCROW VS SWAP MODE:
In case escrow mode is selected, tokens need to be escrowed in Swaps smart contract
before the trade can occur.
In case swap mode is selected, tokens are not escrowed in the Swaps. Instead, the Swaps
contract is only allowed to transfer tokens ON BEHALF of their owners. When trade is
executed, an atomic token swap occurs.

EXPIRATION DATE:
The trade can be cancelled by both parties in case expiration date is passed.

CLAIMS:
The executer has the ability to force or cancel the trade.
In case of disagreement/missing payment, both parties can contact the "executer"
of the trade to deposit a claim and solve the issue.

MARKETPLACE:
The contract can be used as a token marketplace. Indeed, when trades are created
without specifying the recipient address, anyone can purchase them by sending
the requested payment in exchange.

PRICE ORACLES:
When price oracles are defined, those can define the price at which trades need to be executed.
This feature is particularly useful for assets with NAV (net asset value).


### `onlyTokenController(address tokenAddress)`



Modifier to verify if sender is a token controller.

### `onlyPriceOracle(address tokenAddress)`



Modifier to verify if sender is a price oracle.


### `constructor(bool owned)` (public)

[Swaps CONSTRUCTOR]


Initialize Swaps + register
the contract implementation in ERC1820Registry.

### `canReceive(bytes, bytes32, address, address, address, uint256, bytes data, bytes operatorData) → bool` (external)

[ERC1400TokensRecipient INTERFACE (1/2)]


Indicate whether or not the Swaps contract can receive the tokens or not. [USED FOR ERC1400 TOKENS ONLY]


### `tokensReceived(bytes, bytes32 partition, address, address from, address to, uint256 value, bytes data, bytes operatorData)` (external)

[ERC1400TokensRecipient INTERFACE (2/2)]


Hook function executed when tokens are sent to the Swaps contract. [USED FOR ERC1400 TOKENS ONLY]


### `requestTrade(struct Swaps.TradeRequestInput inputData, bytes32 preimage)` (external)



Create a new trade request in the Swaps smart contract.


### `_requestTrade(address holder1, address holder2, address executer, uint256 expirationDate, uint256 settlementDate, struct Swaps.UserTradeData userTradeData1, struct Swaps.UserTradeData userTradeData2)` (internal)



Create a new trade request in the Swaps smart contract.


### `acceptTrade(uint256 index, bytes32 preimage)` (external)



Accept a given trade (+ potentially escrow tokens).


### `_acceptTrade(uint256 index, address sender, uint256 ethValue, uint256 erc1400TokenValue, bytes32 preimage)` (internal)



Accept a given trade (+ potentially escrow tokens).


### `getTradeAcceptanceStatus(uint256 index) → bool` (public)



Verify if a trade has been accepted by the token holders.

The trade needs to be accepted by both parties (token holders) before it gets executed.



### `_allowanceIsProvided(address sender, struct Swaps.UserTradeData userTradeData) → bool` (internal)



Verify if a token allowance has been provided in token smart contract.



### `approveTrade(uint256 index, bool approved)` (external)





### `approveTradeWithPreimage(uint256 index, bool approved, bytes32 preimage)` (public)



Approve a trade (if the tokens involved in the trade are controlled)

This function can only be called by a token controller of one of the tokens involved in the trade.

Indeed, when a token smart contract is controlled by an owner, the owner can decide to open the
secondary market by:
 - Allowlisting the Swaps smart contract
 - Setting "token controllers" in the Swaps smart contract, in order to approve all the trades made with his token



### `getTradeApprovalStatus(uint256 index) → bool` (public)



Verify if a trade has been approved by the token controllers.

In case a given token has token controllers, those need to validate the trade before it gets executed.



### `executeTrade(uint256 index)` (external)





### `executeTradeWithPreimage(uint256 index, bytes32 preimage)` (public)



Execute a trade in the Swaps contract if possible (e.g. if tokens have been esccrowed, in case it is required).

This function can only be called by the executer specified at trade creation.
If no executer is specified, the trade can be launched by anyone.



### `_executeTrade(uint256 index, bytes32 preimage)` (internal)



Execute a trade in the Swaps contract if possible (e.g. if tokens have been esccrowed, in case it is required).


### `forceTrade(uint256 index)` (external)





### `forceTradeWithPreimage(uint256 index, bytes32 preimage)` (public)



Force a trade execution in the Swaps contract by transferring tokens back to their target recipients.


### `cancelTrade(uint256 index)` (external)



Cancel a trade execution in the Swaps contract by transferring tokens back to their initial owners.


### `_transferUsersTokens(uint256 index, enum Swaps.Holder holder, uint256 value, bool revertTransfer, bytes32 preimage)` (internal)





### `_executeHoldOnUsersTokens(uint256 index, enum Swaps.Holder holder, uint256, bool, bytes32 preimage)` (internal)





### `_executeTransferOnUsersTokens(uint256 index, enum Swaps.Holder holder, uint256 value, bool revertTransfer)` (internal)



Internal function to transfer tokens to their recipient by taking the token standard into account.


### `_executeHold(address token, bytes32 tokenHoldId, enum Swaps.Standard tokenStandard, bytes32 preimage, address tokenRecipient)` (internal)





### `_holdExists(address sender, address recipient, struct Swaps.UserTradeData userTradeData) → bool` (internal)





### `_canReceive(bytes data, bytes operatorData) → bool` (internal)



Indicate whether or not the Swaps contract can receive the tokens or not.

By convention, the 32 first bytes of a token transfer to the Swaps smart contract contain a flag.

 - When tokens are transferred to Swaps contract to propose a new trade. The 'data' field starts with the
 following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
 In this case the data structure is the the following:
 <tradeFlag (32 bytes)><recipient address (32 bytes)><executer address (32 bytes)><expiration date (32 bytes)><requested token data (4 * 32 bytes)>

 - When tokens are transferred to Swaps contract to accept an existing trade. The 'data' field starts with the
 following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
 In this case the data structure is the the following:
 <tradeFlag (32 bytes)><request index (32 bytes)>

If the 'data' doesn't start with one of those flags, the Swaps contract won't accept the token transfer.



### `_getTradeFlag(bytes data) → bytes32 flag` (internal)



Retrieve the trade flag from the 'data' field.

By convention, the 32 first bytes of a token transfer to the Swaps smart contract contain a flag.
 - When tokens are transferred to Swaps contract to propose a new trade. The 'data' field starts with the
 following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
 - When tokens are transferred to Swaps contract to accept an existing trade. The 'data' field starts with the
 following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd



### `_getTradeTokenData(bytes data) → struct Swaps.UserTradeData tokenData` (internal)



Retrieve the tokenData from the 'data' field.



### `renounceOwnership()` (public)



Renounce ownership of the contract.

### `tradeExecuters() → address[]` (external)



Get the list of trade executers as defined by the Swaps contract.


### `setTradeExecuters(address[] operators)` (external)



Set list of trade executers for the Swaps contract.


### `_setTradeExecuters(address[] operators)` (internal)



Set list of trade executers for the Swaps contract.


### `tokenControllers(address tokenAddress) → address[]` (external)



Get the list of token controllers for a given token.


### `setTokenControllers(address tokenAddress, address[] operators)` (external)



Set list of token controllers for a given token.


### `priceOracles(address tokenAddress) → address[]` (external)



Get the list of price oracles for a given token.


### `setPriceOracles(address tokenAddress, address[] oracles)` (external)



Set list of price oracles for a given token.


### `_checkPriceOracle(address tokenAddress, address oracle) → bool` (internal)



Check if address is oracle of a given token.


### `getPriceOwnership(address tokenAddress1, address tokenAddress2) → bool` (external)



Get price of the token.


### `setPriceOwnership(address tokenAddress1, address tokenAddress2, bool priceOwnership)` (external)



Take ownership for setting the price of a token.


### `variablePriceStartDate(address tokenAddress) → uint256` (external)



Get date after which the token price can potentially be set by an oracle (0 if price can not be set by an oracle).


### `setVariablePriceStartDate(address tokenAddress, uint256 startDate)` (external)



Set date after which the token price can potentially be set by an oracle (0 if price can not be set by an oracle).


### `getTokenPrice(address tokenAddress1, address tokenAddress2, bytes32 tokenId1, bytes32 tokenId2) → uint256` (external)



Get price of the token.


### `setTokenPrice(address tokenAddress1, address tokenAddress2, bytes32 tokenId1, bytes32 tokenId2, uint256 newPrice)` (external)



Set price of a token.


### `getPrice(uint256 index) → uint256` (public)



Get amount of token2 to pay to acquire the token1.


### `getTrade(uint256 index) → struct Swaps.Trade` (external)



Get the trade.


### `getNbTrades() → uint256` (external)



Get the total number of requests in the Swaps contract.



### `ExecutedHold(address token, bytes32 holdId, bytes32 lockPreimage, address recipient)`



Include token events so they can be parsed by Ethereum clients from the settlement transactions.

### `Transfer(address from, address to, uint256 tokens)`





### `TransferByPartition(bytes32 fromPartition, address operator, address from, address to, uint256 value, bytes data, bytes operatorData)`





### `CreateNote(address owner, bytes32 noteHash, bytes metadata)`





### `DestroyNote(address owner, bytes32 noteHash)`






### `UserTradeData`


address tokenAddress


uint256 tokenValue


bytes32 tokenId


enum Swaps.Standard tokenStandard


bool accepted


bool approved


enum Swaps.TradeType tradeType


### `TradeRequestInput`


address holder1


address holder2


address executer


uint256 expirationDate


address tokenAddress1


uint256 tokenValue1


bytes32 tokenId1


enum Swaps.Standard tokenStandard1


address tokenAddress2


uint256 tokenValue2


bytes32 tokenId2


enum Swaps.Standard tokenStandard2


enum Swaps.TradeType tradeType1


enum Swaps.TradeType tradeType2


uint256 settlementDate


### `Trade`


address holder1


address holder2


address executer


uint256 expirationDate


uint256 settlementDate


struct Swaps.UserTradeData userTradeData1


struct Swaps.UserTradeData userTradeData2


enum Swaps.State state



### `Standard`

















### `State`

















### `TradeType`











### `Holder`








