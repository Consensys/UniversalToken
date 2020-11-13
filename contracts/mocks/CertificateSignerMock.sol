pragma solidity ^0.5.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotPausered" MODIFIER

import "../roles/CertificateSignerRole.sol";


contract CertificateSignerMock is CertificateSignerRole {

  constructor(address token) public {
    _addCertificateSigner(token, msg.sender);
  }

}