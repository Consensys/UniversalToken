# Universal Token

The Universal Token is a token-agnostic, smart contract standard with multiple extensions. 

Extensions, deployed on-chain, are reusable across token deployments and standards. 

Extensions can do the following:

* Add external (user-facing) functions to your token.
* Store additional data for your token.
* Add custom functionality to token transfers.

Using the Universal Token API, developers can deploy smart contract extensions. Token contracts can then plug-and-play these extensions, either at token deployment or in real-time on-chain. 

If you want to jump straight into extension building, head over to the [Extensions](/extensions/extensions) page.

## Getting started

!!! todo
    TODO: How to deploy an ERC20 or ERC721.

## How it works

Extensions live at the address they are deployed to on-chain. All tokens use this address to register the extension.

When a token registers an extension, it deploys a [Storage Proxy](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/extensions/ExtensionStorage.sol) which is where the extension's storage is kept for the registration. This means that extensions *by default* have no sense of global state; each registration is essentially a new deployment of that extension.

Extensions can, therefore, store their own data. The stored data is sandboxed to each token deployment. When a token registers an extension, the extension is initialized and storage is created. This makes writing extension
code easier, because the storage for your smart contract extension is different across deployments (where deployments means registrations). However, extensions *by default* do not have any access to the token's storage or state outside of what is already allowed by the token's standard. 

Extensions can still be granted roles inside a token to perform specialized operations; for example `MinterRole` for an extension that mints tokens.

An example of an extension that a token may want to register is an `AllowListExtension`. This extension only allows addresses with an `AllowListed`
role to make token transfers. The logic for this extension is universal across all token standards [and only requires one smart contract](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/extensions/allowblock/allow/AllowExtension.sol) in this system.

This extension is deployed [on rinkeby](#) and can be registered by any new Universal Token deployment to add this feature to a new token.

## Token Standards Supported

Currently both [ERC20](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/ERC20Extendable.sol) and [ERC721](https://github.com/ConsenSys/UniversalToken/blob/develop/contracts/tokens/ERC721/proxy/ERC721Proxy.sol) have implementations that support extensions. There are plans to add support for [ERC1400](https://github.com/ethereum/eips/issues/1411) and [ERC1155](https://eips.ethereum.org/EIPS/eip-1155). 


    


