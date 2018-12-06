pragma solidity ^0.4.24;


contract CertificateControllerMock {

  function _checkCertificate(bytes data, uint256 amount, bytes4 functionID) internal view returns(bool) {
    if(amount != 0 || functionID != 0x00000000) {} // Line to avoid compilation warnings for unused variables.
    if(data.length > 0 && data[0] == hex"10") {
      return true;
    } else {
      return false;
    }
  }
}
