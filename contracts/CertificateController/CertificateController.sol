pragma solidity ^0.5.0;

import "../mocks/CertificateControllerMock.sol";


contract CertificateController is CertificateControllerMock {

  constructor(address _certificateSigner, bool activated) public CertificateControllerMock(_certificateSigner, activated) {}

}
