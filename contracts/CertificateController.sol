pragma solidity ^0.4.24;


contract CertificateController {

  // Address used by off-chain controller service to sign certificate
  mapping(address => bool) public certificateSigners;

  // A nonce used to ensure a certificate can be used only once
  mapping(address => uint) public checkCount;

  event Checked(address sender);

  constructor(address _certificateSigner) public {
    require(_certificateSigner != address(0), "Constructor Blocked - Valid address required");
    certificateSigners[_certificateSigner] = true;
  }

  /**
   * @dev Modifier to protect methods with certificate control
   */
  modifier isValidCertificate(bytes data) {
    require(_checkCertificate(data, msg.value, 0x00000000), "A3: Transfer Blocked - Sender lockup period not ended");
    _;
  }

  /**
   * @dev Checks if a certificate is correct
   * @param data Certificate to control
   */
  function _checkCertificate(
    bytes data,
    uint256 amount,
    bytes4 functionID
  )
    internal
    returns(bool)
  {
    uint256 counter = checkCount[msg.sender];

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
      if (certificateSigners[ecrecover(hash, v, r, s)]) {
        if(functionID == 0x00000000) {
          // Increment sender check count
          checkCount[msg.sender] += 1;

          emit Checked(msg.sender);
        }
        return true;
      }
    }
    return false;
  }
}
