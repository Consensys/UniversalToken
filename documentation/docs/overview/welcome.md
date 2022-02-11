# Universal Token

The Universal Token is a token agnostic smart contract standard that allows the addition of an extension system on-top of a given token standard. The
goal being that extension code deployed on-chain can be reused across token deployments and possibility across token standards. 

Put more simply, it allows developers to deploy extension smart contracts and tokens can plug-and-play these extensions either at token deployment or 
in real-time on-chain. 

Extensions can 

* Add external (user-facing) functions to your token
* Store additional data for your token
* Add custom functionality to token transfers

The goal of this site is to guide you through how a system like this is possible, how it works and how you can begin to experiment with the smart contracts
here to build your own extensions. 

If you want to jump straight to extension building, head over to the [Extensions](../extensions.md) page to learn more.

## Getting Started

TODO: Write how to deploy an ERC20 or ERC721

## How Does it Work?

Extensions live at whatever address they are deployed to on-chain and all tokens use the same address to register that extension.
When the extension is registered by a token, the token will deploy a [Storage Proxy](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/extensions/ExtensionStorage.sol) which will be the place where the extension's storage is kept for that registration. This means that 
extensions *by default* have no sense of global state and each registration of an extension on a token is essentially a
new deployment of that extension.

This means Extensions can store their own data, and the data stored by the extension is sandboxed to each token deployment. When a 
token registers an extension, the extension is "initialized" and the storage of the extension is created. This makes writing extension
code easier, because you keep the idea that the storage for your smart contract extension will be different across deployments (just replace
deployments with registrations). However, extensions *by default* do not have any access to the token's storage or state outside of what is already 
allowed by the token's standard. Extensions can still be granted roles inside a token to perform specialized operations (for example `MinterRole`), 
for an extension that mints tokens

An example of an extension that a token may want to register is an `AllowListExtension`. This extension only allows addresses with an `AllowListed`
role to make token transfers. The logic for this kind of extension is universal across all token standards [and only requires one smart contract](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/extensions/allowblock/allow/AllowExtension.sol) in this system.

This extension is deployed [here on rinkeby](#) and can be registered by any new Universal Token deployments to add this feature to their token.

## Token Standards Supported

Currently both [ERC20](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/ERC20Extendable.sol) and [ERC721](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/tokens/ERC721/proxy/ERC721Proxy.sol) have implementations that support this system. There are plans to add support for [ERC1400](https://github.com/ethereum/eips/issues/1411) and [ERC1155](https://eips.ethereum.org/EIPS/eip-1155). 

## Table of Contents

1. [Token API](../tokens/token-standards.md)
    1. Token roles
    2. Upgrading
    3. Registering extensions
    4. Enable/Disable extensions
    5. Removing extensions
2. [Extensions](../extensions.md)
    1. Getting Started
    2. Register external functions
    3. Extension Roles
    4. Token Roles
    5. Transfer Events
    6. API 
3. [Smart Contract Architecture](../contracts/overview.md)
    1. Proxies 
        1. Proxy, Storage, Logic Pattern
        2. TokenProxy Contract
        3. Proxy Contracts for a Token Standard
    2. Storage Contracts
        1. ProxyContext
        2. TokenStorage Contract
        3. ExtensionStorage Contract
    3. Logic Contracts for a Token Standard
        1. ERC20Logic
        2. ERC721Logic
        3. Extending logic contracts
        3. Building a custom logic contracts
    4. Extension Support
        1. ExtendableRouter Contract
        2. ExtendableHooks Contract
        3. IExtension interface
        4. IExtensionMetadata interface
4. [Utilities](../utilities/overview.md)
5. [Solidity Docs](../API/index.md)
    


