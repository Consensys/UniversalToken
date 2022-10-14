// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotPausered" MODIFIER

import "../roles/CertificateSignerRole.sol";


contract CertificateSignerMock is CertificateSignerRole {

  constructor(address token) {
    _addCertificateSigner(token, msg.sender);
  }

}