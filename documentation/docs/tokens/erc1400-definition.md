## Codefi-defined standard

* The Codefi ERC1400 contract relies on the interface token here:

  https://github.com/ConsenSys/UniversalToken/blob/master/contracts/IERC1400.sol

* This inherits from the OpenZeppelin ERC20 standard interface and a custom document management interface here:

  https://github.com/ConsenSys/UniversalToken/blob/master/contracts/interface/IERC1643.sol

* The ERC1400 contract relies on a number of other standard utility contract definitions from OpenZeppelin such as SafeMath, Ownable, and the IERC20 interface, as well as custom made contracts such as ERC1820 client and implementer contracts for registry inspection, a minting contract, and a set of token extension contracts.

  https://github.com/ConsenSys/UniversalToken/blob/master/contracts/ERC1400.sol


## Certificate-based token transfers

The UniversalToken uses a `transferWithData` function which extends the ERC20 transfer function with a data parameter.

``` solidity
function transferWithData(address recipient, uint256 value, bytes data)
```

The data field contains a certificate issued by the token owner which ensures the transfer is valid.


### Codefi certificates contain:

* Function ID: the certificate relates to one function only.
* Parameters for validation: the inputs have been validated by the issuer.
* Validity date: certificate cannot be used after this date.
* Nonce: certificate can only be used once. 
* Signature: certificate signed by issuer.

!!! example
    KYC certification.
 


## Certificate controller - deprecated

`CertificateController.sol` and subclasses, as referenced in the README and related instructions, no longer exist and have been replaced by two functions.

### Nonce-based validation 

This  allows control of the order of validation.

``` solidity
function _checkNonceBasedCertificate(
 address token,
   address msgSender,
   bytes memory payloadWithCertificate,
   bytes memory certificate
 )
``` 

!!! note "Reference"
    https://github.com/ConsenSys/UniversalToken/blob/master/contracts/extensions/tokenExtensions/ERC1400TokensValidator.sol#L1300
 
 
### Salt-based when validation 

For when the order should not be controlled such as in the case of batch validations.

``` solidity
function _checkSaltBasedCertificate(
   address token,
   address msgSender,
   bytes memory payloadWithCertificate,
   bytes memory certificate
 )
```

!!! note "Reference"
    https://github.com/ConsenSys/UniversalToken/blob/master/contracts/extensions/tokenExtensions/ERC1400TokensValidator.sol#L1390


 
## Delivery versus payment - renamed to Swaps

Delivery versus payment functionality is implemented by the Swaps contract here:

https://github.com/ConsenSys/UniversalToken/blob/master/contracts/tools/Swaps.sol


## Fund issuing

Fund issuing is taken care of by the FundIssuer contract here:

https://github.com/ConsenSys/UniversalToken/blob/master/contracts/tools/FundIssuer.sol

