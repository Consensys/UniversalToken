pragma solidity ^0.5.0;


// CertificateController comment...
contract CertificateController {

  // If set to 'true', the certificate control is activated
  bool _certificateControllerActivated;

  // Address used by off-chain controller service to sign certificate
  mapping(address => bool) internal _certificateSigners;

  // A nonce used to ensure a certificate can be used only once
  mapping(address => uint256) internal _checkCount;

  event Checked(address sender);

  constructor(address _certificateSigner, bool activated) public {
    _setCertificateSigner(_certificateSigner, true);
    _certificateControllerActivated = activated;
  }

  /**
   * @dev Modifier to protect methods with certificate control
   */
  modifier isValidCertificate(bytes memory data) {

    if(_certificateControllerActivated) {
      require(_certificateSigners[msg.sender] || _checkCertificate(data, 0, 0x00000000), "A3"); // Transfer Blocked - Sender lockup period not ended

      _checkCount[msg.sender] += 1; // Increment sender check count

      emit Checked(msg.sender);
    }

    _;
  }

  /**
   * @dev Modifier to protect methods with certificate control
   */
  /* modifier isValidPayableCertificate(bytes memory data) {

    require(_certificateSigners[msg.sender] || _checkCertificate(data, msg.value, 0x00000000), "A3"); // Transfer Blocked - Sender lockup period not ended

    _checkCount[msg.sender] += 1; // Increment sender check count

    emit Checked(msg.sender);
    _;
  } */


  /**
   * @dev Get number of transations already sent to this contract by the sender
   * @param sender Address whom to check the counter of.
   * @return uint256 Number of transaction already sent to this contract.
   */
  function checkCount(address sender) external view returns (uint256) {
    return _checkCount[sender];
  }

  /**
   * @dev Get certificate signer authorization for an operator.
   * @param operator Address whom to check the certificate signer authorization for.
   * @return bool 'true' if operator is authorized as certificate signer, 'false' if not.
   */
  function certificateSigners(address operator) external view returns (bool) {
    return _certificateSigners[operator];
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
    uint256 counter = _checkCount[msg.sender];

    uint256 e;
    bytes32 r;
    bytes32 s;
    uint8 v;

    // Certificate should be 97 bytes long
    if (data.length != 97) {
      return false;
    }

    // Extract certificate information and expiration time from payload
    assembly {
      // Retrieve expirationTime & ECDSA elements from certificate which is a 97 long bytes
      // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
      e := mload(add(data, 0x20))
      r := mload(add(data, 0x40))
      s := mload(add(data, 0x60))
      v := byte(0, mload(add(data, 0x80)))
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
        let payloadsize := sub(calldatasize, 160)
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
        counter
      );
      bytes32 hash = keccak256(pack);

      // Check if certificate match expected transactions parameters
      if (_certificateSigners[ecrecover(hash, v, r, s)]) {
        return true;
      }
    }
    return false;
  }
}
