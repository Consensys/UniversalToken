pragma solidity ^0.5.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotPausered" MODIFIER

import "../extensions/tokenExtensions/roles/CertificateSignerRole.sol";


contract CertificateSignerMock is CertificateSignerRole {

  bool _mockActivated;

  constructor(address token) public {
    _addCertificateSigner(token, msg.sender);
  }

  function mockFunction(address token, bool mockActivated) external onlyCertificateSigner(token) {
    _mockActivated = mockActivated;
  }

}