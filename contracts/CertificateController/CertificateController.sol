pragma solidity ^0.4.24;

import "../mocks/CertificateControllerMock.sol";

contract CertificateController is CertificateControllerMock {

  constructor(address _certificateSigner) public CertificateControllerMock(_certificateSigner) {}

}
