![Codefi](images/DVP/codefi.png)

# What is Codefi?

Codefi is an advanced institutional technology platform for issuing and exchanging tokenized financial assets, powered by the Ethereum blockchain. The security token implementations used by the platform are shared in this repository.
Codefi is a product created by ConsenSys.


# Delivery-vs-payment smart contract description

## Objective

The purpose of the contract is to allow secure token transfers/exchanges between 2 stakeholders (called holder1 and holder2).
It is used for secondary market assets transfers.

From now on, an operation in the DVP smart contract (transfer/exchange) is called a trade.
Depending on the type of trade, one/multiple token transfers will be executed.

## How does it work?

The simplified workflow is the following:
1. A trade request is created in the DVP smart contract, it specifies:
```
- The token holder(s) involved in the trade
- The trade executer (optional)
- An expiration date
- Details on the first token (address, requested amount, standard)
- Details on the second token (address, requested amount, standard)
- Whether the tokens need to be escrowed in the DVP contract or not
- The current status of the trade (pending / executed / forced / cancelled)
```
2. The trade is accepted by both token holders
3. [OPTIONAL] The trade is approved by token controllers (only if requested by tokens controllers)
4. The trade is executed (either by the executer in case the executer is specified, or by anyone)

![dvp](images/DVP/dvp.png)

# Features

#### Standard-agnostic
The DVP smart contract is standard-agnostic, it supports ETH, ERC20, ERC721, ERC1400.
The advantage of using an ERC1400 token is to leverages its hook property, thus requiring ONE single
transaction (operatorTransferByPartition()) to send tokens to the DVP smart contract instead of TWO
with the ERC20 token standard (approve() + transferFrom()).

#### Off-chain payment
The contract can be used as escrow contract while waiting for an off-chain payment.
Once payment is received off-chain, the token sender realeases the tokens escrowed in
the DVP contract to deliver them to the recipient.

#### Escrow vs swap mode
In case escrow mode is selected, tokens need to be escrowed in DVP smart contract
before the trade can occur.
In case swap mode is selected, tokens are not escrowed in the DVP. Instead, the DVP
contract is only allowed to transfer tokens ON BEHALF of their owners. When trade is
executed, an atomic token swap occurs.

#### Expiration date
The trade can be cancelled by both parties in case expiration date is passed.

#### Claims
The executer has the ability to force or cancel the trade.
In case of disagreement/missing payment, both parties can contact the "executer"
of the trade to deposit a claim and solve the issue.

#### Marketplace
The contract can be used as a token marketplace. Indeed, when trades are created
without specifying the recipient address, anyone can purchase them by sending
the requested payment in exchange.

#### Price oracles
When price oracles are defined, those can define the price at which trades need to be executed.
This feature is particularly useful for assets with NAV (net asset value).


# Use case examples

The DVP contract can be used for multiple use cases:

### Use case 1: Tokens are escrowed in the DVP contract while payment is made off-chain

![UseCase1](images/DVP/usecase1.png)

### Use case 2: Tokens are escrowed in the DVP contract while payment is made on-chain (with another token)

![UseCase2](images/DVP/usecase2.png)

### Use case 3: Swap authorization is provided to the DVP contract, but tokens are not escrowed in the DVP contract

![UseCase3](images/DVP/usecase3.png)

### Use case 4: Marketplace

![UseCase4](images/DVP/usecase4.png)


## Quick start: How to test the contract?

Prerequisites: please make sure you installed "yarn" on your environment.
```bash
brew install yarn
```

Test the smart contract, by running the following commands:
```bash
git clone git@gitlab.com:ConsenSys/client/fr/dauriel/smart-contracts/ERC1400DVP.git
cd ERC1400DVP
yarn install
yarn coverage
```

## How to deploy the contract on a blokchain network?

#### Step1: Define Ethereum wallet and Ethereum network to use in ".env" file

A few environment variables need to be specified. Those can be added to a ".env" file: a template of it can be generated with the following command:
```bash
yarn env
```

The ".env" template contains the following variables:

MNEMONIC - Ethereum wallets which will be used to sign the transactions - [**MANDATORY**] (see section "How to get a MNEMONIC?" in appendix)

INFURA_API_KEY - Key to access an Ethereum node via Infura service (for connection to mainnet or ropsten network) - [OPTIONAL - Only required if NETWORK = mainnet/ropsten] (see section "How to get an INFURA_API_KEY?" in appendix)

#### Step2: Deploy contract

**Deploy contract on ganache**

In case ganache is not installed:
```bash
yarn global add ganache-cli
```
Then launch ganache:
```bash
ganache-cli
```

In a different console, deploy the contract by running the migration script:
```bash
yarn truffle migrate
```

**Deploy contract on ropsten**

Deploy the contract by running the migration script:
```bash
yarn truffle migrate --network ropsten
```

## APPENDIX

### How to get a MNEMONIC?

#### 1.Find a MNEMONIC

There are 2 options to get MNEMONIC:
 - Either generate 12 random words on https://iancoleman.io/bip39/ (BIP39 Mnemonic).
 - Or get the MNEMONIC generated by ganache with the following command:
```bash
ganache-cli
```
The second option is recommended for development purposes since the wallets associated to the MNEMONIC will be pre-loaded with ETH for tests on ganache.

#### 2.Load the wallet associated to the MNEMONIC with ether

If you've used ganache to generate your MNEMONIC and you only want to perform tests on ganache, you have nothing to do. The accounts are already loaded with 100 ETH.

For all other networks than ganache, you have to send ether to the accounts associated to the MNEMONIC:
 - Discover the accounts associated to your MNEMONIC thanks to https://www.myetherwallet.com/#view-wallet-info > Mnemonic phrase.
 - Send ether to those accounts.

### How to get an `INFURA_API_KEY`?

`INFURA_API_KEY` can be generated by creating an account on https://infura.io/
