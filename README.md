![dAuriel](/uploads/2489352dae4903fe54f96831a39743af/dAuriel.png)

# What is dAuriel?

dAuriel is an advanced institutional technology platform for issuing and exchanging tokenized financial assets, powered by the Ethereum blockchain.
dAuriel is a product created by ConsenSys.

# Content - Security token implementations (ERC777 and ERC1400), adapted for financial asset tokenization.

This repo contains security token smart contract implementations used by dAuriel:
#### ERC777 implementation - Advanced token standard for asset transfers.

 - Empowerment of operators with the ability to send tokens on behalf of other addresses.
 - Setup of send/receive hooks to offer token holders more control over their tokens.
 - Use of ERC820 to notify contracts and regular addresses when they receive tokens.
 - Backwards compatible with ERC20.


#### ERC1400 implementation - Partially fungible token standard.

 - Differentiated ownership / transparent restrictions.
 - Controller operations (force transfer).
 - On-chain restriction checking with error signalling, off-chain data injection for transfer restrictions and issuance / redemption semantics.
 - Document management.
 - Backwards compatible with ERC20 and ERC777.

# Objective - Financial asset issuance & management.

The current capital market still needs to overcome a few pain points:
 - Today, it is cumbersome and costly to issue an asset.
 - Once issued, the assets are mainly reserved for high-ticket investors.
 - Finally, those asset are not easily tradable, which strongly limits the secondary market possibilities.

With dAuriel, we want to tokenize the capital market to tackle those pain points. In the new system we imagine:
 - An asset issuance will be faster, simpler but also cheaper than today.
 - This reduction of costs will allow us to onboard smaller ticket investors.
 - Globally, the tokenization removes constraints for more liquid and frictionless asset transfers, while keeping a strong control over the market, thus liberating the secondary market.

The security token standards contained in this repository, combined to user-friendly interfaces, can be leveraged for financial asset issuance & management:

![dAurielInterface](/uploads/966e30a32dd5e10fdc24ce2e6d14603d/dAurielInterface.png)

# Approach - Introduce a new transfer standard to provide issuers with strong control capabilities over their financial assets.

### Introduction.

Currently the most common and well-known standard within crypto community is the [ERC20](https://eips.ethereum.org/EIPS/eip-20).
While the vast majority of ICOs are based on this ERC20 standard, it appears not to be the most relevant for financial asset tokenization.
The only parameters required to perform an ERC20 token transfer are the recipient's address and the value of the transfer, thus limiting the control possibilities over transfers:
```
function transfer(address recipient, uint256 value)
```
All controls have to be hard-coded on-chain and are often limited to simple/binary checks e.g. checking whether an investor is blacklisted or not.

dAuriel makes use of more evolved/granular controls to secure transfers.
Those controls can evolve quickly and require flexibility, which makes it difficult to hard-code them on-chain.

### dAuriel transaction - A way to secure all transfers with a certificate generated off-chain by the issuer.

The use of an additional 'data' parameter in the transfer functions can enable more evolved/granular controls:
```
function transferWithData(address recipient, uint256 value, bytes data)
```
dAuriel fosters to use this additional 'data' field (available in ERC777 and ERC1400 standards) to inject a certificate generated off-chain by the issuer.
A token transfer shall be conditioned to the validity of the certificate, thus offering the issuer with strong control capabilities over its financial assets.

![dAurielTransaction](/uploads/3c2d2122ddc97a23bb4f00e5f9acdfec/dAurielTransaction.png)

The certificate contains:
 - The function ID which ensures the certificate can’t be used on an other function.
 - The parameters which ensures the input parameters have been validated by the issuer.
 - A validity date which ensures the certificate can’t be used after validity date.
 - A nonce which ensures the certificate can’t be used twice.
Finally the certificate is signed by the issuer which ensures it is authentic.

![dAurielCertificate](/uploads/f5c30d15cf0b917e975bed50b3707a3f/dAurielCertificate.png)

# Detailed presentation - Standards description & implementation choices.

### ERC777

The official proposal can be found at: [eips.ethereum.org/EIPS/eip-777](https://eips.ethereum.org/EIPS/eip-777).

The standard implements the [following interface](https://gitlab.com/ConsenSys/client/fr/dauriel/securities-smart-contracts/blob/master/contracts/token/ERC777/IERC777.sol):
```
interface IERC777 {

  function name() external view returns (string); // 1/13
  function symbol() external view returns (string); // 2/13
  function totalSupply() external view returns (uint256); // 3/13
  function balanceOf(address owner) external view returns (uint256); // 4/13
  function granularity() external view returns (uint256); // 5/13

  function controllers() external view returns (address[]); // 6/13
  function authorizeOperator(address operator) external; // 7/13
  function revokeOperator(address operator) external; // 8/13
  function isOperatorFor(address operator, address tokenHolder) external view returns (bool); // 9/13

  function transferWithData(address to, uint256 value, bytes data) external; // 10/13
  function transferFromWithData(address from, address to, uint256 value, bytes data, bytes operatorData) external; // 11/13

  function burn(uint256 value, bytes data) external; // 12/13
  function operatorBurn(address from, uint256 value, bytes data, bytes operatorData) external; // 13/13

  event TransferWithData(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256 value,
    bytes data,
    bytes operatorData
  );
  event Minted(address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);
  event Burned(address indexed operator, address indexed from, uint256 value, bytes data, bytes operatorData);
  event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
  event RevokedOperator(address indexed operator, address indexed tokenHolder);

}
```



# Quick start.

Test the smart contract, by running the following commands:
```
$ git clone https://gitlab.com/ConsenSys/client/fr/dauriel/securities-smart-contracts.git
$ cd securities-smart-contracts
$ make init
$ make coverage
```
Prerequisites: please make sure you installed "truffle", "make", "g++"" on your device.

#### Install your own personal blockchain for Ethereum development.

```
$ yarn global add ganache-cli
```
or
```
$ npm i ganache-cli
```

#### Setup environment variables.

Before deploying the contract you need to generate and fill the file containing all environment variables ('.env' file).

Generate the '.env' file with the following command:
```
$ node setup.js
```

Open the '.env' Replace the fake variable values. Here's an example '.env' file:
```
$ INFURA_API_KEY=a420aed2329e49f7ab09f2ba1efb38fc
$ SOLIDITY_COVERAGE=
$ MNEMONIC=brain surround have swap horror body response double fire dumb bring hazard
```

INFURA_API_KEY can be generated by creating an account on https://infura.io/

There are 2 options to get MNEMONIC:

Option 1 [RECOMMENDED]: MNEMONIC can be filled by re-using the wallet generated by ganache:
```
$ ganache-cli
```
This option is recommended since the wallet will be pre-loaded with ETH for tests on ganache.

Option 2: MNEMONIC can also be obtained by generating 12 random words on https://iancoleman.io/bip39/ (BIP39 Mnemonic).

#### Send ETH to the address corresponding to your MNEMONIC.

There are 2 options to recover the ETH address corresponding to your MNEMONIC:

Option 1 [RECOMMENDED]: Launch ganache to generate your wallet. It contains 10 pre-loaded accounts. Your can take account (0) as address:
```
$ ganache-cli
```
It is already loaded with 100 ETH, so you have nothing to do.

Option 2:
Discover the wallet associated to your MNEMONIC on https://www.myetherwallet.com/#view-wallet-info > Mnemonic phrase.
Send ETH to the first address of this wallet in order to be able to send transactions with it.

#### Deploy contract on ganache.

Deploy the contract by running the migration scripts:
```
$ truffle migrate
```

#### Deploy contract on ropsten.

Start building the contract (this generates the concatenated solidity files required to publish the contract on blockchan explorers like Etherscan, Kaleido, etc.):
```
$ yarn run build
```

Deploy the contract by running the migration scripts:
```
$ truffle migrate --network ropsten
```

Export contract parameters in export.txt file:
```
$ node export.js
```
