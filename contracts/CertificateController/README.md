## Description of certificate controllers and implementation choice (nonce vs salt)

### The certificate controller, a way to perform multi-signature in a single transaction

Certificate controllers can be used by any smart contract requiring the verification of an approval generated off-chain.
In the frame of Codefi Assets, the certificate controller is used by the ERC1400 token contract, to ensure, the token transfer requested by an investor, is indeed approved by the issuer.

The certificate controller performs an ec-recover operation on the provided certificate, in order to recover the signature of the certificate signer. The signature, which in the frame of Codefi Assets usually is the issuer's signature, is then compared the list of signatures authorized by the contract.

In a way, it can be seen as a way to perform multi-signature, with one single transaction instead of two: every transaction contains both the signature of the investor (transaction signature) AND the signature of the issuer (certificate signature).

### How to use the certificate controller?

The smart contract which requires to verify certificates needs to:
 - Inherit from the certificate controller
 - Add a `data` parameter in final position for the functions which require a certificate validation
 - Add a modifier `isValidCertificate(data)` to the functions which require a certificate validation

An off-chain certificate generator module is of course required to create the certificates (it is not part of this repo).

### Nonce-based VS Salt based certificate controllers

There are 2 ways to ensure a certificate can't be used twice:
 - Either introduce a local nonce for each user which is incremented by 1 every time a certificate is used
 - Either introduce a salt generated randomly which is stored in mapping every time a certificate is used

The advantage of the nonce-based certificate, is it enables the issuer to control the order in which the transactions can be validated by the network.
But this advantage can also be a problem, in the case when the issuer generates a batch of certificates for the investor without knowing the order they will be sent to the network. In this specific case of certificate batches, it is more relevant to use the salt based certificate.

## Warning

### Description

The certificate controllers (`CertificateControllerNonce` and `CertificateControllerSalt`) are used by passing a signature as a final argument in a function call. This signature is over the other arguments to the function. Specifically, the signature must match the call data that precedes the signature.

The way this is implemented assumes standard ABI encoding of parameters, but there's actually some room for manipulation by a malicious user. This manipulation can allow the user to change some of the call data without invalidating the signature.

The following code is from `CertificateControllerNonce`, but similar logic applies to `CertificateControllerSalt`:

**code2/contracts/CertificateControllerNonce.sol:L127-L134**
```solidity
bytes memory payload;

assembly {
  let payloadsize := sub(calldatasize, 160)
  payload := mload(0x40) // allocate new memory
  mstore(0x40, add(payload, and(add(add(payloadsize, 0x20), 0x1f), not(0x1f)))) // boolean trick for padding to 0x40
  mstore(payload, payloadsize) // set length
  calldatacopy(add(add(payload, 0x20), 4), 4, sub(payloadsize, 4))
```

Here the signature is over all call data except the final 160 bytes. 160 bytes makes sense because the byte array is length 97, and it's preceded by a 32-byte size. This is a total of 129 bytes, and typical ABI encoded pads this to the next multiple of 32, which is 160.

If an attacker does _not_ pad their arguments, they can use just 129 bytes for the signature or even 128 bytes if the `v` value happens to be 0. This means that when checking the signature, not only will the signature be excluded, but also the 31 or 32 bytes that come before the signature. This means the attacker can call a function with a different final argument than the one that was signed.

That final argument is, in many cases, the number of tokens to transfer, redeem, or issue.

### Mitigating factors

For this to be exploitable, the attacker has to be able to obtain a signature over shortened call data.

If the signer accepts raw arguments and does its own ABI encoding with standard padding, then there's likely no opportunity for an attacker to exploit this vulnerability. (They can shorten the call data length when they make the function call later, but the signature won't match.)

### Remediation

This potential vulnerability can be addressed at the signing layer (off chain) by doing the ABI encoding there and denying an attacker the opportunity to construct their own call data.

