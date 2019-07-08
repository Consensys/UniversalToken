![CoFi](images/CoFiLogo.png)

## What is CoFi OS?

CoFi OS is an advanced institutional technology platform for issuing and exchanging tokenized financial assets, powered by the Ethereum blockchain. The security token implementations used by the platform are shared in this repository.
CoFi OS is a product created by ConsenSys.

Example of an asset issuance leveraging the CoFi OS technology:

![CoFiVideo](images/CoFiVideo.png)
https://youtu.be/r2zvd7u5Uv0


Slide deck presenting ERC1400 features:
![ERC1400](images/ERC1400.png)
https://docs.google.com/presentation/d/e/2PACX-1vS6pUx-VjdwSfELQwFVlXzq3Ekvxa9wpGTrNJqkp6-CnHxBPecjTEcVq21V6Nsbc-Bp4yq4dZTtp6Kn/pub?start=false&loop=false&delayms=3000

## Content - Security token implementations, adapted for financial asset tokenization: ERC777 (ERC1400Raw) and ERC1400

This repo contains security token smart contract implementations used by CoFi OS:
#### ERC777 (ERC1400Raw) implementation - Advanced token standard for asset transfers

 - Empowerment of operators with the ability to send tokens on behalf of other addresses.
 - Setup of send/receive hooks to offer token holders more control over their tokens.
 - Use of ERC1820([eips.ethereum.org/EIPS/eip-1820](http://eips.ethereum.org/EIPS/eip-1820)) to notify contracts and regular addresses when they receive tokens.
 - Backwards compatible with ERC20.

 WARNING - NAMING:
 The token standard implementation contained in this repo was renamed ERC1400Raw (instead of ERC777) as it is not 100% compliant with the official ERC777 interface. Indeed, it implements the same logic as ERC777 but functions have been renamed to better fit with the ERC1400 interface:
 - defaultOperators --> controllers
 - isOperatorFor --> isOperator
 - send --> transferWithData
 - operatorSend --> transferFromWithData
 - burn --> redeem
 - operatorBurn --> redeemFrom
 - mint --> issue
 - Sent event --> TransferWithData event
 - Minted event --> Issued event
 - Burned event --> Redeemed event

 Furthermore, the hooks have been enhanced to support partitions and become ERC1400-compliant:
 - IERC777TokensSender --> IERC1400TokensSender
 - IERC777TokensRecipient --> IERC1400TokensRecipient


#### ERC1400 implementation - Partially fungible token standard

 - Differentiated ownership / transparent restrictions.
 - Controller operations (force transfer).
 - On-chain restriction checking with error signaling, off-chain data injection for transfer restrictions and issuance / redemption semantics.
 - Document management.
 - Backwards compatible with ERC20.

## Objective - Financial asset issuance & management

The current capital market still needs to overcome a few pain points:
 - Today, it is cumbersome and costly to issue an asset.
 - Once issued, the assets are mainly reserved for high-ticket investors.
 - Finally, those assets are not easily tradable, which strongly limits the secondary market possibilities.

With CoFi OS, we want to tokenize the capital market to tackle those pain points. In the new system, we imagine:
 - An asset issuance will be faster, simpler but also cheaper than today.
 - This reduction of costs will allow us to onboard smaller ticket investors.
 - Globally, the tokenization removes constraints for more liquid and frictionless asset transfers, while keeping a strong control over the market, thus liberating the secondary market.

The security token standards contained in this repository, combined to user-friendly interfaces, can be leveraged for financial asset issuance & management:

![CoFiInterface](images/CoFiInterface.png)

## Approach - Introduce a new transfer standard to provide issuers with strong control capabilities over their financial assets

### Introduction - The limits of ERC20 token standard

Currently the most common and well-known standard within crypto community is the ERC20([eips.ethereum.org/EIPS/eip-20](https://eips.ethereum.org/EIPS/eip-20)).
While the vast majority of ICOs are based on this ERC20 standard, it appears not to be the most relevant for financial asset tokenization.
The only parameters required to perform an ERC20 token transfer are the recipient's address and the value of the transfer, thus limiting the control possibilities over transfers:
```
function transfer(address recipient, uint256 value)
```
All controls have to be hard-coded on-chain and are often limited to simple / binary checks e.g. checking whether an investor is blacklisted or not.

CoFi OS makes use of more evolved / granular controls to secure transfers.
Those controls can evolve quickly and require flexibility, which makes it difficult to hard-code them on-chain.

### CoFi transaction - A way to secure all transfers with a certificate generated off-chain by the issuer

The use of an additional 'data' parameter in the transfer functions can enable more evolved / granular controls:
```
function transferWithData(address recipient, uint256 value, bytes data)
```
CoFi OS fosters to use this additional 'data' field, available in ERC777 (ERC1400Raw) and ERC1400 standards, in order to inject a certificate generated off-chain by the issuer.
A token transfer shall be conditioned to the validity of the certificate, thus offering the issuer with strong control capabilities over its financial assets.

![CoFiTransaction](images/CoFiTransaction.png)

### CoFi certificate - A way to perform advanced conditional ownership

The CoFi certificate contains:
 - The function ID which ensures the certificate can’t be used on an other function.
 - The parameters which ensures the input parameters have been validated by the issuer.
 - A validity date which ensures the certificate can’t be used after validity date.
 - A nonce which ensures the certificate can’t be used twice.

Finally the certificate is signed by the issuer which ensures it is authentic.

The certificate enables the issuer to perform advanced conditional ownership, since he needs to be aware of all parameters of a function call before generating the associated certificate.

![CoFiCertificate](images/CoFiCertificate.png)

PS: Since the ERC1400 standard is agnostic about the way to control certificate, we didn't include our certificate controller in this repository (a mock is used instead). In order to perform real advanced conditional ownership, a certificate controller called 'CertificateController.sol' shall be placed in folder '/contracts/CertificateController' instead of the mock placed there.

## Detailed presentation - Standards description & implementation choices

### ERC777 (ERC1400Raw)

The [ERC777 (ERC1400Raw)](contracts/token/ERC1400Raw/ERC1400Raw.sol) is an advanced token standard adapted for regulated asset transfers, since it allows to inject data (i.e. our certificate) in the transfer transactions:
```
function transferWithData(address recipient, uint256 value, bytes data)
```

The official proposal can be found at: [eips.ethereum.org/EIPS/eip-777](https://eips.ethereum.org/EIPS/eip-777).

We've performed a few updates compared to the official proposal, mainly to better fit with our implementation of ERC1400:
 - Introduction of the notion of 'controllers' (replacing defaultOperators) for better consistency with ERC1400 'controllers'.
 - Introduction of '_isControllable' property (set to 'false' by default for the ERC777 (ERC1400Raw), but set to 'true' for the ERC1400).
 - Update of IERC777TokensRecipient and IERC777TokensSender interfaces, by adding 'partition' parameters, and renaming into IERC1400TokensRecipient and IERC1400TokensSender in order to make the hooks ERC1400-compliant.
 - Renaming of 'send' function (now 'transferWithData') and 'Sent' event (now 'TransferWithData') for better consistency with ERC1400 names + to avoid potential issues with blockchain tools (e.g. Truffle, etc.) considering 'send' as a reserved word.
 - Renaming of 'mint' function (now 'issue') and 'Minted' event (now 'Issued') for better consistency with ERC1400 names.
 - Renaming of 'burn' function (now 'redeem') and 'Burned' event (now 'Redeemed') for better consistency with ERC1400 names.
 - Renaming of 'operatorBurn' function (now 'redeemFrom') for better consistency with ERC1400 names.

ERC777 (ERC1400Raw) can be made compatible with ERC20 (see [ERC1400RawERC20.sol](contracts/token/ERC20/ERC1400RawERC20.sol)).
This backwards compatibility property offers interoperability, as ERC20 tokens are compatible with most existing exchange platforms.

It implements the [following interface](contracts/token/ERC1400Raw/IERC1400Raw.sol):
```
interface IERC1400Raw {

  function name() external view returns (string);
  function symbol() external view returns (string);
  function totalSupply() external view returns (uint256);
  function balanceOf(address owner) external view returns (uint256);
  function granularity() external view returns (uint256);

  function controllers() external view returns (address[]);
  function authorizeOperator(address operator) external;
  function revokeOperator(address operator) external;
  function isOperator(address operator, address tokenHolder) external view returns (bool);

  function transferWithData(address to, uint256 value, bytes data) external;
  function transferFromWithData(address from, address to, uint256 value, bytes data, bytes operatorData) external;

  function redeem(uint256 value, bytes data) external;
  function redeemFrom(address from, uint256 value, bytes data, bytes operatorData) external;

  event TransferWithData(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256 value,
    bytes data,
    bytes operatorData
  );
  event Issued(address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);
  event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data, bytes operatorData);
  event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
  event RevokedOperator(address indexed operator, address indexed tokenHolder);

}
```

### ERC1400

The [ERC1400](contracts/ERC1400.sol) has an additional feature on top of ERC777 (ERC1400Raw) properties: the partial fungibility property.
This property allows to perform corporate actions, like mergers and acquisitions, which is essential for financial assets.

The original submission with discussion can be found at: [github.com/ethereum/EIPs/issues/1411](https://github.com/ethereum/EIPs/issues/1411).

We've performed a few updates compared to the original submission, mainly to fit with business requirements + to save gas cost of contract deployment:
 - Compatibility with ERC777 (ERC1400Raw) as all ERC777 (ERC1400Raw) properties are business requirements for financial asset tokenization (incl. send/receive hooks and ERC1820 which are used to ensure transfer atomicity).
 - Modification of view functions ('canTransferByPartition', 'canOperatorTransferByPartition') as consequence of our certificate design choice: the view functions need to have the exact same parameters as 'transferByPartition' and 'operatorTransferByPartition' in order to be in measure to confirm the certificate's validity.
 - Removal of controller functions ('controllerTransfer' and 'controllerRedeem') and events ('ControllerTransfer' and 'ControllerRedemption') to save gas cost of contract deployment. Those controller functionalities have been included in 'transferByPartition' and 'redeemByPartition' functions instead.
 - Split of ERC1400 functions into 2 interfaces (IERC1400Partition for asset transfer logic + IERC1400 for asset issuance/redemption logic) for better readability.

ERC1400 is compatible with ERC777 (ERC1400Raw) and can be made compatible with ERC20 (see [ERC1400ERC20.sol](contracts/token/ERC20/ERC1400ERC20.sol)).
This backwards compatibility property offers interoperability, as ERC20 tokens are compatible with most existing exchange platforms.

The standard implements the following interfaces: [IERC1400Partition](contracts/token/ERC1400Partition/IERC1400Partition.sol) + [IERC1400](contracts/IERC1400.sol):
```
interface IERC1400Partition {

    // Token Information
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256);
    function partitionsOf(address tokenHolder) external view returns (bytes32[]);

    // Token Transfers
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes data) external returns (bytes32);
    function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes data, bytes operatorData) external returns (bytes32);

    // Default Partition Management
    function getDefaultPartitions(address tokenHolder) external view returns (bytes32[]);
    function setDefaultPartitions(bytes32[] partitions) external;

    // Operators
    function controllersByPartition(bytes32 partition) external view returns (address[]);
    function authorizeOperatorByPartition(bytes32 partition, address operator) external;
    function revokeOperatorByPartition(bytes32 partition, address operator) external;
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool);

    // Transfer Events
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

    // Operator Events
    event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

}
```

```
interface IERC1400  {

    // Document Management
    function getDocument(bytes32 name) external view returns (string, bytes32);
    function setDocument(bytes32 name, string uri, bytes32 documentHash) external;
    event Document(bytes32 indexed name, string uri, bytes32 documentHash);

    // Controller Operation
    function isControllable() external view returns (bool);

    // Token Issuance
    function isIssuable() external view returns (bool);
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes data) external;
    event IssuedByPartition(bytes32 indexed partition, address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);

    // Token Redemption
    function redeemByPartition(bytes32 partition, uint256 value, bytes data) external;
    function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes data, bytes operatorData) external;
    event RedeemedByPartition(bytes32 indexed partition, address indexed operator, address indexed from, uint256 value, bytes data, bytes operatorData);

    // Transfer Validity
    function canTransferByPartition(bytes32 partition, address to, uint256 value, bytes data) external view returns (byte, bytes32, bytes32);
    function canOperatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes data, bytes operatorData) external view returns (byte, bytes32, bytes32);

}
```

## Quick start: How to test the contract?

Prerequisites: please make sure you installed "yarn" on your environment.
```
$ brew install yarn
```

Test the smart contract, by running the following commands:
```
$ git clone git@github.com:ConsenSys/ERC1400.git
$ cd ERC1400
$ yarn
$ yarn coverage
```

## How to deploy the contract on a blokchain network?

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
$ ganache-cli
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
