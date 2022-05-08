![Codefi](images/CodefiBanner.png)

The Universal Token is a smart-contract framework for creating customisable tokens. Tokens created following the framework are composed of a Token contract to which one or multiple Extension contracts can be connected. 

The Universal Token is compatible with Ethereum’s most used token standards including ERC20, ERC721, ERC1155 and ERC1400.  

Dapp developers may use the Universal Token framework to:
- Easily add new features to a token contract
- Reduce the size of a token contract by not deploying and importing unnecessary code
- Reduce development effort by leveraging a library of reusable token contracts and extension contracts

Using the Universal Token API, developers can deploy extensions contracts and plug extensions contract to Token contracts, either at token deployment or in real-time on-chain.

# Quickstart

## Building

The easiest way to get started is by first compiling all contracts 

```shell
yarn build
```

## Deploying a Token

deploying the `ERC20` smart contract requires an `ERC20Logic` contract to be already deployed on-chain

### Truffle

```javascript
  const ERC20Logic = artifacts.require("ERC20Logic");
  const logic = await ERC20Logic.new();
```

### Hardhat

```javascript
  const ERC20Logic = await hre.ethers.getContractFactory("ERC20Logic");
  const logic = await ERC20Logic.deploy();
  await logic.deployed();
```

When you have an `ERC20Logic` contract address, you can now deploy the `ERC20` contract

### Truffle

```javascript
  const ERC20 = artifacts.require("ERC20");
  const token = await ERC20.new(
    "ERC20Extendable", //Token Name
    "DAU",             //Token Symbol
    true,              //Allow Minting?
    true,              //Allow Burning?
    deployer,          //The owner address for this token
    initialSupply,     //The inital supply for this token (will be given to owner address)
    maxSupply,         //The absolute max supply for this token
    logic.address      //The address of the ERC20Logic contract
  );
```

### Hardhat

```javascript
  const ERC20 = await hre.ethers.getContractFactory("ERC20");
  const token = await ERC20.deploy(
    "ERC20Extendable", //Token Name
    "DAU",             //Token Symbol
    true,              //Allow Minting?
    true,              //Allow Burning?
    deployer,          //The owner address for this token
    initialSupply,     //The inital supply for this token (will be given to owner address)
    maxSupply,         //The absolute max supply for this token
    logic.address      //The address of the ERC20Logic contract
  );
  await erc20.deployed();
```

## Extensions Included

Extensions are a key part of the UniversalToken, the repo comes with 5 extensions ready to be used with a deployed token.

* AllowExtension
  - Only allowlisted addresses can transfer/mint/burn tokens
* BlockExtensions
  - Blocklisted addresses cannot transfer/mint/burn tokens
* PauseExtension
  - Pause all transfer/mint/burns or pause transfer/mint/burns for a specific address
* HoldExtension
  - Token holds are an alternative to escrows allowing to lock tokens while keeping them in the wallet of the investor.

## Deploying Extensions

Before you can attach an extension to your token you must first deploy the extension on-chain. If the extension
is already deployed on-chain then you can skip this step. There shouldn't be any constructor arguments when deploying
an extension, as these arguments will not be accessible by the Extension when it's attached to the token

### Truffle

```javascript
  const AllowExtension = artifacts.require("AllowExtension");
  const allowExtContract = await AllowExtension.new();
```

### Hardhat

```javascript
  const AllowExtension = await hre.ethers.getContractFactory("AllowExtension");
  const allowExtContract = await AllowExtension.deploy();
  await allowExtContract.deployed();
```

## Registering Extensions

Once an extension is deployed on-chain and you have the extension's contract address, you can register the extension to a deployed token. To register an extension, simply use the `function registerExtension(address extension)` function. 

**NOTE: This function can only be executed by the current token manager address. To determine the current token manager address, you can use the `function manager() public view returns (address)` function.**

```javascript
    await token.registerExtension(allowExtContract.address);
```

# Building Extensions

Extensions are smart contracts that give a token contract additional functionality. A common use-case is to have finer control over the conditions of a token transfer, however there are others, such as adding DeFi support built in or price oracles. 

Extensions live on-chain and can be used by many different token contracts at the same time. Each token contract extension registration is independent and keeps its own independent storage. Extension contracts are upgradable by default and therefore follow the same storage rules as [proxy pattern](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#storage-collisions-between-implementation-versions).

## Getting Started

First import the `TokenExtension` and `TransferData` from the `TokenExtension.sol` file

```solidity
import {TokenExtension, TransferData} from "@consensys-software/UniversalToken/extensions/TokenExtension.sol";
```

Once you have thesee imported, you can create a new contract that inherits from `TokenExtension` with an empty constructor and override the `initialize` function

```solidity
import {TokenExtension, TransferData} from "@consensys-software/UniversalToken/extensions/TokenExtension.sol";

contract PauseExtension is TokenExtension {

    constructor() {

    }

    function initialize() external override {

    }
}
```

## Extension Constructor

Even though extensions are upgradable, they must contain a constructor. The constructor of an extension smart contract is used to write immutable metadata about the extension that is used by the token during registration. This includes things such as the version, the functions the extension has, what interfaces it supports, and which token interfaces it supports (multiple token interfaces can be supported). Each new version of an extension deployed on-chain must include this constructor, and may choose to change the contents of the constructor between versions. 

Extensions must call the following inside the constructor

* `_setPackageName(string)` - Set the package name for the extension
* `_setInterfaceLabel(string)` - Set the interface label for the extension
* `_setVersion(uint)` - Set the version n umber for the extension

Optionally, extensions may also call the following inside the constructor

* `_registerFunction(bytes4)` - Register a function selector to be added to the token. If this function is invoked on the token, then this extension instance will be invoked
* `_registerFunctionName(string)` - Same as `_registerFunction(bytes4)`, however lets you specify a function by its function signature
* `_requireRole(bytes32)` - Specify a token role Id that this extension requires. For example, if this extension needs to mint tokens then you should invoke `_requireRole(TOKEN_MINTER_ROLE)`
* `_supportsTokenStandard(TokenStandard)` - Specify a specific token standard that this extension supports.
* `_supportsAllTokenStandards()` - Specify that this extension supports all token standards
* `_supportInterface(bytes4)` - Specify a specific interface label that this extension supports

Example:

```solidity
import {TokenExtension, TransferData} from "@consensys-software/UniversalToken/extensions/TokenExtension.sol";

contract PriceOracleExtension is TokenExtension {

    constructor() {
        _setVersion(1);
        _registerFunction(ExampleExtension.fetchPrice.selector);
        _registerFunction(ExampleExtension.updatePrice.selector);
        _supportsAllTokenStandards();
    }

    function initialize() external override {
        // ...
    }
    
    function updatePrice() external returns (uint256) {
        // ...
    }
 
    function fetchPrice() external view returns (uint256) {
        // ...
    }

}
```

## Token Events

Extensinos can choose to listen to specific token events on-chain (such as transfers or approvals) to trigger specific checks or actions. The `TokenExtension` base contract provides helper methods to listen to common token events.

The only thing extensions cannot do inside an event callback is perform an action that would cause the same event to be triggered again. This is to prevent reentry attacks and potential recurrsion problems.

* `_listenForTokenTransfers(function (TransferData memory) external returns (bool) callback)` - Listen for token transfers and invoke the provided callback function. When the callback is invoked, the transfer has already occured
* `_listenForTokenApprovals(function (TransferData memory) external returns (bool) callback)` - Listen for token approvals and invoke the provided callback function. When the callback is invoked, the approval has already occured
* `_listenForTokenBeforeTransfers(function (TransferData memory) external returns (bool) callback)` - Listen for token transfers and invoke the provided callback function. The callback is invoked right before the transfer occurs

If an extension wishes to listen to an event, it should subscribe to the event inside its `initialize` function. However, an extension can choose to subscirbe whenever they like.

**NOTE: It's very important that event callback functions are marked as either `external` or `public` and MUST include the `onlyToken` modifier. The `onlyToken` modifier ensures that only the token can execute the callback function

```solidity
import {TokenExtension, TransferData} from "@consensys-software/UniversalToken/extensions/TokenExtension.sol";

contract PauseExtension is TokenExtension {
    bytes32 constant internal ALLOWLIST_ROLE = keccak256("allowblock.roles.allowlisted");
    
    constructor() {
        // ...
    }

    function initialize() external override {
        _listenForTokenTransfers(this.onTransferExecuted);
    }
    
    function onTransferExecuted(TransferData memory data) external onlyToken returns (bool) {
        // hasRole is provided by the TokenExtension base contract
        bool fromAllowed = data.from == address(0) || hasRole(data.from, ALLOWLIST_ROLE);
        bool toAllowed = data.to == address(0) || hasRole(data.to, ALLOWLIST_ROLE);
        
        require(fromAllowed, "from address is not allowlisted");
        require(toAllowed, "to address is not allowlisted");

        return fromAllowed && toAllowed;
    }
}
```
