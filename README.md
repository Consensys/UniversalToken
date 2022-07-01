![Codefi](images/CodefiBanner.png)

[![Run tests](https://github.com/ConsenSys/va-platform-extendable-tokens-pkg/actions/workflows/pr.yml/badge.svg)](https://github.com/ConsenSys/va-platform-extendable-tokens-pkg/actions/workflows/pr.yml)

The Universal Token is a smart-contract framework for creating customisable tokens. Tokens created following the framework are composed of a Token contract to which one or multiple Extension contracts can be connected. 

The Universal Token is compatible with Ethereum’s most used token standards including ERC20, ERC721, ERC1155 and ERC1400.  

Dapp developers may use the Universal Token framework to:
- Easily add new features to a token contract
- Reduce the size of a token contract by not deploying and importing unnecessary code
- Reduce development effort by leveraging a library of reusable token contracts and extension contracts

Using the Universal Token API, developers can deploy extensions contracts and plug extensions contract to Token contracts, either at token deployment or in real-time on-chain.

# Quickstart

The repo uses Truffle to manage unit tests, deployment scripts and migrations. 

There are several Truffle exec scripts to get started with the extendable UniversalToken framework. Before you can interact with the scripts, you must install the required dependencies.

```shell
yarn
```

# Building

The easiest way to get started is by first compiling all contracts 

```shell
yarn build
```
