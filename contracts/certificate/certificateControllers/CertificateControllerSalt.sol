/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;


// CertificateController comment...
contract CertificateController {

  // If set to 'true', the certificate control is activated
  bool _certificateControllerActivated;

  // Address used by off-chain controller service to sign certificate
  mapping(address => bool) internal _certificateSigners;

  // A nonce used to ensure a certificate can be used only once
  /* mapping(address => uint256) internal _checkCount; */

  // A nonce used to ensure a certificate can be used only once
  mapping(bytes32 => bool) internal _usedCertificate;

  event Used(address sender);

  constructor(address _certificateSigner, bool activated) public {
    _setCertificateSigner(_certificateSigner, true);
    _certificateControllerActivated = activated;
  }

  /**
   * @dev Modifier to protect methods with certificate control
   */
  modifier isValidCertificate(bytes memory data) {

    if(_certificateControllerActivated) {
      require(_certificateSigners[msg.sender] || _checkCertificate(data, 0, 0x00000000), "54"); // 0x54	transfers halted (contract paused)

      bytes32 salt;
      assembly {
        salt := mload(add(data, 0x20))
      }

      _usedCertificate[salt] = true; // Use certificate

      emit Used(msg.sender);
    }
    
    _;
  }

  /**
   * @dev Modifier to protect methods with certificate control
   */
  /* modifier isValidPayableCertificate(bytes memory data) {

    require(_certificateSigners[msg.sender] || _checkCertificate(data, msg.value, 0x00000000), "54"); // 0x54	transfers halted (contract paused)

    bytes32 salt;
    assembly {
      salt := mload(add(data, 0x20))
    }

    _usedCertificate[salt] = true; // Use certificate

    emit Used(msg.sender);
    _;
  } */

  /**
   * @dev Get state of certificate (used or not).
   * @param salt First 32 bytes of certificate whose validity is being checked.
   * @return bool 'true' if certificate is already used, 'false' if not.
   */
  function isUsedCertificate(bytes32 salt) external view returns (bool) {
    return _usedCertificate[salt];
  }

  /**
   * @dev Set signer authorization for operator.
   * @param operator Address to add/remove as a certificate signer.
   * @param authorized 'true' if operator shall be accepted as certificate signer, 'false' if not.
   */
  function _setCertificateSigner(address operator, bool authorized) internal {
    require(operator != address(0)); // Action Blocked - Not a valid address
    _certificateSigners[operator] = authorized;
  }

  /**
   * @dev Get activation status of certificate controller.
   */
  function certificateControllerActivated() external view returns (bool) {
    return _certificateControllerActivated;
  }

  /**
   * @dev Activate/disactivate certificate controller.
   * @param activated 'true', if the certificate control shall be activated, 'false' if not.
   */
  function _setCertificateControllerActivated(bool activated) internal {
    _certificateControllerActivated = activated;
  }

  /**
   * @dev Checks if a certificate is correct
   * @param data Certificate to control
   */
  function _checkCertificate(
    bytes memory data,
    uint256 amount,
    bytes4 functionID
  )
    internal
    view
    returns(bool)
  {
    bytes32 salt;
    uint256 e;
    bytes32 r;
    bytes32 s;
    uint8 v;

    // Certificate should be 129 bytes long
    if (data.length != 129) {
      return false;
    }

    // Extract certificate information and expiration time from payload
    assembly {
      // Retrieve expirationTime & ECDSA elements from certificate which is a 97 long bytes
      // Certificate encoding format is: <salt (32 bytes)>@<expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
      salt := mload(add(data, 0x20))
      e := mload(add(data, 0x40))
      r := mload(add(data, 0x60))
      s := mload(add(data, 0x80))
      v := byte(0, mload(add(data, 0xa0)))
    }

    // Certificate should not be expired
    if (e < now) {
      return false;
    }

    if (v < 27) {
      v += 27;
    }

    // Perform ecrecover to ensure message information corresponds to certificate
    if (v == 27 || v == 28) {
      // Extract payload and remove data argument
      bytes memory payload;

      assembly {
        let payloadsize := sub(calldatasize, 192)
        payload := mload(0x40) // allocate new memory
        mstore(0x40, add(payload, and(add(add(payloadsize, 0x20), 0x1f), not(0x1f)))) // boolean trick for padding to 0x40
        mstore(payload, payloadsize) // set length
        calldatacopy(add(add(payload, 0x20), 4), 4, sub(payloadsize, 4))
      }

      if(functionID == 0x00000000) {
        assembly {
          calldatacopy(add(payload, 0x20), 0, 4)
        }
      } else {
        for (uint i = 0; i < 4; i++) { // replace 4 bytes corresponding to function selector
          payload[i] = functionID[i];
        }
      }

      // Pack and hash
      bytes memory pack = abi.encodePacked(
        msg.sender,
        this,
        amount,
        payload,
        e,
        salt
      );
      bytes32 hash = keccak256(pack);

      // Check if certificate match expected transactions parameters
      if (_certificateSigners[ecrecover(hash, v, r, s)] && !_usedCertificate[salt]) {
        return true;
      }
    }
    return false;
  }
}
