![Codefi](images/CodefiBanner.png)

# Overview of the repo
 - [Universal Token For Assets and Payments](https://github.com/ConsenSys/ERC1400/blob/master/README.md)
 - [Certificate-based token transfers](contracts/certificate/README.md)
 - [Delivery-vs-payment](contracts/tools/Swaps.md)
 - [Fund issuance](contracts/tools/FundIssuer.md)

# Introduction

Never heard of tokenization
  
  --> See introduction [here](https://medium.com/@consensyscodefi/how-to-explain-tokenization-to-six-year-olds-well-sort-of-consensys-codefi-a40780c5d4ca).

Never hear of Universal Token for Assets and Payments
  
  --> See webinar recording [here](https://www.youtube.com/watch?v=rlWO9rPL06U&feature=youtu.be).
  
  --> See blog article [here](https://codefi.consensys.net/blog/understanding-the-universal-token-for-assets-and-payments).

Blockchain technology and more specifically the emergence of "programmable" tokens have opened a world of new possibilities for financial assets: the creation of digital assets.
Digital assets are financial assets, which have been "tokenized". This means each asset is represented by a token on the blockchain.

As introduced by the [token taxonomy framework](https://github.com/token-taxonomy-consortium/TokenTaxonomyFramework), there are 3 main categories of tokens:
 - **Fungible tokens**: Fungible tokens are all identical and cannot be distinguished from each other. Each individual token is essentially interchangeable, like US dollars, company shares, or ounces of gold. This is probably the simplest and most common category of tokens.
 - **Non-fungible tokens**: A non-fungible token is unique. Non-fungible tokens (NFTs) are used to create verifiable digital scarcity, as well as representing asset ownership of things like real estate, luxury goods, works of art, or collectible objects in video games (CryptoKitties is an early example). Essentially, NFTs are used for items which require a unique digital fingerprint.
 - **Hybrid tokens**: Hybrid tokens are a mix of both. Each token belongs to a class (sometimes also called category/partition/tranche). Inside a given class, all tokens are the same: they are fungible. But tokens from different classes can be distinguished from each other: they are non-fungible. **By combining both advantages of fungibility and non-fungibility, hybrid tokens often appear as a relevant way to represent financial assets.**

 ![Picture8](images/Picture9.png)
 
Token standards have emerged in the Ethereum community.

**ERC20** is the most basic and most adopted token standard. It can be seen as the "axiom of fungible token standards" and is compatible with the majority of existing tools and platforms.

**ERC1400** is a hybrid token standard precisely designed for the use case of tokenized financial assets:
 - By being ERC20 retrocompatible, it remains compatible with the majority of existing tools and platforms.
 - By being partially-fungible (hybrid token), it allows to represent different classes of assets, perform more evolved token actions (lock tokens, collateralize tokens, etc.), which is essential in the context of corporate actions.
 - By offering the possibility to attach data to transfers, strong control over token transfers, based on granular certificate checks can be setup by issuers.

The following repository contains the ERC1400 implementation used by the Codefi Assets platform.

# Why do we need a Universal Token for Assets and Payments?

 ![Picture10](images/Picture10.png)

When we started developing the token, we knew that the future would sit at the intersection of traditional finance and decentralized finance. Our ambition was to find a way to create a bridge between both worlds.
But as of today, those 2 have very different characteristics:
 - DeCentralised finance is still reserved mainly for crypto-friendly investors, and has difficulties attracting more traditional ones
 - Traditional finance still requires strong control capabilities over issued assets, while DeFi fosters more on simplicity of access and processes automation
 - Finally the first one relies on trust in the law, and financial institutions, while the latter relies on trust in the code

Now the question is:
 - How do we reconcile those 2 worlds?
 - How do we increase the diversity and the volume of assets in the DeFi world?
 - How can we release traditional assets in the DeFi economy, in order to benefit from the advantages it provides?

 ![Picture11](images/Picture11.png)

The future looks like this. 
A world where DeFi automation mechanisms are extended to traditional assets, while remaining compliant with existing regulatory constraints.

Of course this can not happen in one day, and Codefi’s mission is to make the transition painless.
We want to SMOOTHLY introduce traditional investors to the world of DeFi, without ignoring requirements of the existing system.

Today, DeFi is still reserved for “early adopters”.
Accepting the constraints of the existing system (strong issuer or regulator control capabilities, legal agreements, investor verification, etc.) is the only way to convince the “early majority” to adopt a new mindset.

Building upon the existing system is the only way to increase adoption.

# What are the main challenges to overcome?

 ![Picture12](images/Picture12.png)

4 major requirements to overcome, to make the CeFi <> DeFi convergence a reality are the following:
 - **Adapted control mechanisms**: it’s a legal requirement for asset issuers in traditional finance to be empowered with strong control capabilities over issued assets
 - **Permanent reliability of investor registry**: asset issuers are accountable for maintaining a reliable investor registry
 - **Certainty of execution for delivery-vs-payment**: delivery-vs-payment operations on the secondary market, need to be the result of mechanisms that can not fail
 - **Interoperability with the Ethereum ecosystem**: all those requirements need to be taken into account while remaining compatible with the Ethereum ecosystem and more specifically with the DeFi tools

We’ll now deep dive into those 4 requirements to see what essential features a universal token for assets and payments shall offer.

## Interoperability with the Ethereum ecosystem

 ![Picture13](images/Picture13.png)

#### ERC20 interface
One of the things that Ethereum has done best is its token standards.
The whole Ethereum community has reached consensus on those standards.
A rich ecosystem of tools and platforms has emerged.
The most well-known token standard is called ERC20: it is an interface for fungible tokens.

Its “transfer” and “balanceOf” functions are now pre-requisites to be compatible with wallets and key custody solutions, like Metamask of Ledger hardware wallets.

Its “allowance” and “transferFrom” functions are important for interoperability with other smart contracts.
Airswap p2p trading plaform uses those functions to execute delivery-vs-payment operations.

#### Possibility to escrow tokens
Another important aspect for interoperability is the possibility to escrow tokens.

Escrow a token means accepting a smart contract to be the owner of the token (instead of a human person).
Token escrow mechanisms are used by lots of DeFi smart contract:
 - Lending contracts like Compound need escrows to store collateralized tokens
 - Decentralized exchanges like Uniswap or derivatives platforms like Synthetix need escrows to create liquidity pools

In the end, an ERC20 interface + the possibility to escrow tokens are mandatory to be compatible with the Ethereum ecosystem.

## Control Mechanisms

Second major topic for assets and payments is control mechanisms.

 ![Picture14](images/Picture14.png)

When building financial instruments, controlling who has access to a specific instrument is paramount.
Every asset distribution, or asset transfer needs to be controlled by the issuer of the asset.
There are two main solution that we’ve implemented.
 - **Certificates generated off-chain**: a certificate is a signed hash of the transaction parameters. A new certificate needs to be created for every new transfer. This offers very strong control capabilities. But unfortunately, it is not compatible with the ERC20 interface, thus making things more complex when it comes towards interoperability with the Ethereum ecosystem.
 - **List of validated investors stored on-chain**: the token smart contract just consults this list every time it needs to perform a transfer. In the future, we can envision a world where such global allowlists will be curated by consortiums of financial institutions or even regulators themselves, but today, those don’t exist. This method lacks flexibility since an Ethereum transaction is required everytime we need to modify the list. But the good thing is, it allows to use the ERC20 transfer function, thus making it interoperable with the Ethereum ecosystem.


 ![Picture15](images/Picture15.png)

In traditional finance, correct maintenance of a registry is the responsibility of very large institutions, like central security depositories, transfer agent or even issuers themselves in some cases. These institutions must retain full control over the registry. 
When the token is configured to be “controllable”, it provides the issuer with the capability to force token transfers, token creation, or destruction.

It is not the case in DeFi, where no one but the token holder can decide to transfer a token.
This is seen by some as a really powerful feature, moving trust at the core of a protocol rather than in a public or private authority.

Both setups, controllable or not, can be adapted, depending on the use case, and the “renounceControl” function allows to switch from one setup to the other.

## Reliability of investor registry

 ![Picture16](images/Picture16.png)

When moving traditional securities on a public blockchain network, a fundamental principle needs to be respected: the created ownership registry shall at all time, reflect the beneficial holder of the assets. 

Problem is, when this requirement is not compatible with the escrow mechanism.
Indeed, on the right of this picture, when Joe escrow’s 4 token in an escrow contract, the owner of the token is the escrow contract and not Joe.
This makes it complicated, or even sometimes impossible to know, that Joe is the beneficial owner of the assets.
We lose the one essential feature of the blockchain as registry maintenance tool. 

Initially, the reason why we need to send tokens to an escrow, is to lock them and make sure they CAN'T be spent.

Token holds, that you can see on the left of the image, are an alternative to escrows, allowing to lock tokens while keeping them in the wallet of the investor.
The good point with token holds is they preserve the investor registry, and ensure at any time we know who is the beneficial owner of the asset.

Token holds are also very useful when it comes to distributing dividends to investors, in proportion to the amount of token they own, because we’re sure the investor registry is reliable.

## Certainty of Execution for Delivery-vs-Payment

 ![Picture17](images/Picture17.png)

Delivery-vs-payment is an operation that consists in exchanging token representing cash against tokens representing assets.
Delivery-vs-payment is a very powerful blockchain use case, as it can be done without middleman, but with certainty of execution.

#### Allowances and escrows

In today’s DeFi, most DvP use cases either rely on allowances or escrows in order to manage token exchanges.
Both allowances and escrows are not optimal:
 - **Allowance mechanisms** don’t provide certainty of execution for delivery vs payment (since the allowance doesn’t prevent the user for spending his tokens for something else after he has created a trade order)
 - **Escrow mechanisms** do provide certainty of execution, but as described above, escrows do not preserve the accuracy of the registry (since the escrow contract becomes the owner of the tokens, instead of the investor). 

#### Token holds

Since allowances and escrows are not optimal, we’ve decided to use holds.
A hold, similarly to an allowance, is an authorization created by the token holder, to allow someone else to transfer his tokens on his behalf.
But a hold goes further than an allowance, by forbidding the holder to spend the tokens for something else, once the hold is created.
The tokens are like locked on his own account.

Delivery-vs-payment based on token holds combines both:
 - The advantage of the escrow, that tokens can not be spent for something else before the trade execution
 - The advantage of the allowance, that preserves a reliable token registry 

#### HTLC (Hash Time Locked Contract)

Moreover, token holds are compatible with HTLC mechanism.
HTLC is a useful mechanism (description will be added soon) that allows to manage cases where atomic delivery-vs-payment can not be performed:
 - Either when the cash token and asset tokens are on 2 different blockchain networks
 - Or when the cash token and asset tokens are private smart contracts (privacy groups, or zkAssets)

# What shall the Universal Token for Assets and Payments look like?

With all requirements detailed above in mind, here’s and overview of the universal token for assets and payments.

 ![Picture18](images/Picture18.png)

As belonging to the hybrid token category, it benefits from both:
 - Advantages of fungibility
 - Advantages of non-fungibility

It combines all requirements listed in this presentation:
 - For **control mechanisms**, it offers a module for certificate checks and a module for allowlist checks + it offers the possibility to force transfers
 - For **reliability of investor registry**, it provides a module to create token holds
 - For **certainty of delivery-vs-payment execution**, it includes token holds for atomic Swaps, and HTLC mechanism for non-atomic Swaps
 - For **interoperability**, it offers an ERC20 interface

The features can be turned ON and OFF during the token’s lifecycle.

We believe this modular approach offers enough flexibility to satisfy both traditional stakeholders and crypto-friendly publics,
in order to make the DeFi <> CeFi convergence a reality.

 ![Picture19](images/Picture19.png)

The hybrid structure of the token even allows, to setup different modules for the different classes of the token:
 - some classes can be setup for traditional finance, by being controllable, and including the certificate module
 - other classes can be setup for decentralized finance, and rely on an allowlist module

Tokens can switch from a token class to another, with an on-ramp/off-ramp mechanism.

Moving tokens from a class to another allows to easily change how they are controlled. 

This means the token allows to operate on both CeFi and DeFi at the same time:
 - **Rigth now**, financial instruments can be issued with a setup adapted to the current regulatory context
 - **Later**, the setup can be gradually adapted for Decentralized Finance when the regulation becomes clearer


 ![Picture20](images/Picture20.png)

In conclusion, universal token is modular, evolutive, and can be adapted to multiple use cases, thus making it a relevant standard to achieve unification of 2 worlds.

The possibility to turn features on and off at any time, allows to transition from CeFi to DeFi while keeping the same token.

The evolution of the law will allow traditional finance to slowly migrate towards more “decentralized” setups.
On the other hand, DeFi tools’ interface will evolve to become compatible with a higher number of standards (by supporting token holds, certificates, etc.).


# What is Codefi Assets?

Codefi Assets is an advanced institutional technology platform for issuance and management of tokenized financial assets, powered by the Ethereum blockchain. Codefi Assets is a product created by ConsenSys.

https://codefi.consensys.net/codefiassets

### A platform for financial asset issuance & management

The current capital market still needs to overcome a few pain points:
 - Today, it is cumbersome and costly to issue an asset.
 - Once issued, the assets are mainly reserved for high-ticket investors.
 - Finally, those assets are not easily tradeable, which strongly limits the secondary market possibilities.

With Codefi Assets, we want to tokenize the capital market to tackle those pain points. In the new system, we imagine:
 - An asset issuance will be faster, simpler but also cheaper than today.
 - This reduction of costs will allow us to onboard smaller ticket investors.
 - Globally, the tokenization removes constraints for more liquid and frictionless asset transfers, while keeping a strong control over the market, thus liberating the secondary market.

### Video demo of an asset issuance platform based on Codefi Assets technology

![CodefiVideo](images/CodefiVideo.png)

Link to video:
https://www.youtube.com/watch?v=EWneY6Q_0ag&feature=youtu.be&ab_channel=MatthieuBouchaud


# Quick overview of token standards (ERC20, ERC1400) 

![Picture1](images/Picture1.png)
![Picture2](images/Picture2.png)
![Picture3](images/Picture3.png)
![Picture4](images/Picture4.png)

# Description of ERC1400 standard

ERC1400 introduces new concepts on top of ERC20 token standard:
 - **Granular transfer controls**: Possibility to perform granular controls on the transfers with a system of certificates (injected in the additional `data` field of the transfer method)
 - **Controllers**: Empowerment of controllers with the ability to send tokens on behalf of other addresses (e.g. force transfer).
 - **Partionned tokens** (partial-fungibility): Every ERC1400 token can be partitioned. The partition of a token, can be seen as the state of a token. It is well adapted for representing, classes of assets, performing corporate actions, etc.
 - **Document management**: Possibility to bind tokens to hashes of legal documents, thus making the link between a blockchain transaction and the real world.

Optionally, the following features can also be added:
 - **Hooks**: Possibility for token senders/recipients to setup hooks, e.g. automated actions executed everytime they send/receive tokens, thanks to [ERC1820](http://eips.ethereum.org/EIPS/eip-1820).
 - **Upgradeability**: Use of ERC1820([eips.ethereum.org/EIPS/eip-1820](http://eips.ethereum.org/EIPS/eip-1820)) as central contract registry to follow smart contract migrations.


# Focus on ERC1400 implementation choices

This implementation has been developed based on EIP-spec interface defined by the [security token roundtable](https://github.com/SecurityTokenStandard/EIP-Spec/blob/master/eip/eip-1400.md).

We've performed a few updates compared to the original submission, mainly to fit with business requirements + to save gas cost of contract deployment.

#### Choices made to fit with business requirements
 - Introduction of sender/recipient hooks ([IERC1400TokensRecipient](contracts/extensions/userExtensions/IERC1400TokensRecipient.sol), [IERC1400TokensSender](contracts/extensions/userExtensions/IERC1400TokensSender.sol)). Those are inspired by [ERC777 hooks]((https://eips.ethereum.org/EIPS/eip-777)), but they have been updated in order to support partitions, in order to become ERC1400-compliant.
 - Modification of view functions ('canTransferByPartition', 'canOperatorTransferByPartition') as consequence of our certificate design choice: the view functions need to have the exact same parameters as 'transferByPartition' and 'operatorTransferByPartition' in order to be in measure to confirm the certificate's validity.
 - Introduction of validator hook ([IERC1400TokensValidator](contracts/extensions/tokenExtensions/IERC1400TokensValidator.sol)), to manage updates of the transfer validation policy across time (certificate, allowlist, blocklist, lock-up periods, investor caps, pauseability, etc.), thanks an upgradeable module.
 - Extension of ERC20's allowance feature to support partitions, in order to become ERC1400-compliant. This is particularly important for secondary market and delivery-vs-payment.
 - Possibility to migrate contract, and register new address in ERC1820 central registry, for smart contract upgradeability.

#### Choices made to save gas cost of contract deployment
 - Removal of controller functions ('controllerTransfer' and 'controllerRedeem') and events ('ControllerTransfer' and 'ControllerRedemption') to save gas cost of contract deployment. Those controller functionalities have been included in 'operatorTransferByPartition' and 'operatorRedeemByPartition' functions instead.
 - Export of 'canTransferByPartition' and 'canOperatorTransferByPartition' in optional checker hook [IERC1400TokensChecker](contracts/extensions/tokenExtensions/IERC1400TokensChecker.sol) as those functions take a lot of place, although they are not essential, as the result they return can be deduced by calling other view functions of the contract.

NB: The original submission with discussion can be found at: [github.com/ethereum/EIPs/issues/1411](https://github.com/ethereum/EIPs/issues/1411).

# Interfaces

#### ERC1400 interface

The [IERC1400 interface](contracts/IERC1400.sol) of this implementation is the following:
```
interface IERC1400 /*is IERC20*/ { // Interfaces can currently not inherit interfaces, but IERC1400 shall include IERC20

  // ****************** Document Management *******************
  function getDocument(bytes32 name) external view returns (string memory, bytes32);
  function setDocument(bytes32 name, string calldata uri, bytes32 documentHash) external;

  // ******************* Token Information ********************
  function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256);
  function partitionsOf(address tokenHolder) external view returns (bytes32[] memory);

  // *********************** Transfers ************************
  function transferWithData(address to, uint256 value, bytes calldata data) external;
  function transferFromWithData(address from, address to, uint256 value, bytes calldata data) external;

  // *************** Partition Token Transfers ****************
  function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external returns (bytes32);
  function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bytes32);

  // ****************** Controller Operation ******************
  function isControllable() external view returns (bool);
  // function controllerTransfer(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external; // removed because same action can be achieved with "operatorTransferByPartition"
  // function controllerRedeem(address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData) external; // removed because same action can be achieved with "operatorRedeemByPartition"

  // ****************** Operator Management *******************
  function authorizeOperator(address operator) external;
  function revokeOperator(address operator) external;
  function authorizeOperatorByPartition(bytes32 partition, address operator) external;
  function revokeOperatorByPartition(bytes32 partition, address operator) external;

  // ****************** Operator Information ******************
  function isOperator(address operator, address tokenHolder) external view returns (bool);
  function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool);

  // ********************* Token Issuance *********************
  function isIssuable() external view returns (bool);
  function issue(address tokenHolder, uint256 value, bytes calldata data) external;
  function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external;

  // ******************** Token Redemption ********************
  function redeem(uint256 value, bytes calldata data) external;
  function redeemFrom(address tokenHolder, uint256 value, bytes calldata data) external;
  function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external;
  function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata operatorData) external;

  // ******************* Transfer Validity ********************
  // We use different transfer validity functions because those described in the interface don't allow to verify the certificate's validity.
  // Indeed, verifying the ecrtificate's validity requires to keeps the function's arguments in the exact same order as the transfer function.
  //
  // function canTransfer(address to, uint256 value, bytes calldata data) external view returns (byte, bytes32);
  // function canTransferFrom(address from, address to, uint256 value, bytes calldata data) external view returns (byte, bytes32);
  // function canTransferByPartition(address from, address to, bytes32 partition, uint256 value, bytes calldata data) external view returns (byte, bytes32, bytes32);    

  // ******************* Controller Events ********************
  // We don't use this event as we don't use "controllerTransfer"
  //   event ControllerTransfer(
  //       address controller,
  //       address indexed from,
  //       address indexed to,
  //       uint256 value,
  //       bytes data,
  //       bytes operatorData
  //   );
  //
  // We don't use this event as we don't use "controllerRedeem"
  //   event ControllerRedemption(
  //       address controller,
  //       address indexed tokenHolder,
  //       uint256 value,
  //       bytes data,
  //       bytes operatorData
  //   );

  // ******************** Document Events *********************
  event Document(bytes32 indexed name, string uri, bytes32 documentHash);

  // ******************** Transfer Events *********************
  event TransferByPartition(
      bytes32 indexed fromPartition,
      address operator,
      address indexed from,
      address indexed to,
      uint256 value,
      bytes data,
      bytes operatorData
  );

  event ChangedPartition(
      bytes32 indexed fromPartition,
      bytes32 indexed toPartition,
      uint256 value
  );

  // ******************** Operator Events *********************
  event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
  event RevokedOperator(address indexed operator, address indexed tokenHolder);
  event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
  event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

  // ************** Issuance / Redemption Events **************
  event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
  event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);
  event IssuedByPartition(bytes32 indexed partition, address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);
  event RedeemedByPartition(bytes32 indexed partition, address indexed operator, address indexed from, uint256 value, bytes operatorData);

}
```

#### ERC1066 interface for reason codes

To improve the token holder experience, canTransfer MUST return a reason byte code on success or failure based on the [ERC1066](https://ethereum-magicians.org/t/erc-1066-ethereum-status-codes-esc/283/24) application-specific status codes specified below. An implementation can also return arbitrary data as a bytes32 to provide additional information not captured by the reason code.
```
 * Code	Reason
 * 0x50	transfer failure
 * 0x51	transfer success
 * 0x52	insufficient balance
 * 0x53	insufficient allowance
 * 0x54	transfers halted (contract paused)
 * 0x55	funds locked (lockup period)
 * 0x56	invalid sender
 * 0x57	invalid receiver
 * 0x58	invalid operator (transfer agent)
 * 0x59	
 * 0x5a	
 * 0x5b	
 * 0x5a	
 * 0x5b	
 * 0x5c	
 * 0x5d	
 * 0x5e	
 * 0x5f	token meta or info
```


## Quick start: How to test the contract?

Prerequisites: please make sure you installed "yarn" on your environment.
```
$ brew install yarn
$ brew install nvm
```

Test the smart contract, by running the following commands:
```
$ git clone https://github.com/ConsenSys/UniversalToken.git
$ cd UniversalToken
$ nvm use
$ yarn
$ yarn coverage
```


## How to deploy the contract on a blockchain network?

#### Step1: Define Ethereum wallet and Ethereum network to use in ".env" file

A few environment variables need to be specified. Those can be added to a ".env" file: a template of it can be generated with the following command:
```
$ yarn env
```

The ".env" template contains the following variables:

MNEMONIC - Ethereum wallets which will be used by the webservice to sign the transactions - [**MANDATORY**] (see section "How to get a MNEMONIC?" in appendix)

INFURA_API_KEY - Key to access an Ethereum node via Infura service (for connection to mainnet or ropsten network) - [OPTIONAL - Only required if NETWORK = mainnet/ropsten] (see section "How to get an INFURA_API_KEY?" in appendix)

#### Step2: Deploy contract

**Deploy contract on ganache**

In case ganache is not installed:
```
$ yarn global add ganache-cli
```
Then launch ganache:
```
$ ganache-cli -p 7545
```

In a different console, deploy the contract by running the migration script:
```
$ yarn truffle migrate
```

**Deploy contract on ropsten**

Deploy the contract by running the migration script:
```
$ yarn truffle migrate --network ropsten
```


## APPENDIX

### How to get a MNEMONIC?

#### 1.Find a MNEMONIC

There are 2 options to get MNEMONIC:
 - Either generate 12 random words on https://iancoleman.io/bip39/ (BIP39 Mnemonic).
 - Or get the MNEMONIC generated by ganache with the following command:
```
$ ganache-cli
```
The second option is recommended for development purposes since the wallets associated to the MNEMONIC will be pre-loaded with ETH for tests on ganache.

#### 2.Load the wallet associated to the MNEMONIC with ether

If you've used ganache to generate your MNEMONIC and you only want to perform tests on ganache, you have nothing to do. The accounts are already loaded with 100 ETH.

For all other networks than ganache, you have to send ether to the accounts associated to the MNEMONIC:
 - Discover the accounts associated to your MNEMONIC thanks to https://www.myetherwallet.com/#view-wallet-info > Mnemonic phrase.
 - Send ether to those accounts.

### How to get an INFURA_API_KEY?

INFURA_API_KEY can be generated by creating an account on https://infura.io/
