pragma solidity ^0.4.24;

import "../CertificateController.sol";

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * @title ControlledMock
 * @dev Mock class to test certificate controller
 */
contract ControlledMock is Ownable, CertificateController {

  constructor(address certificateSigner)
    public
    CertificateController(certificateSigner)
  {}

  /**
   * @dev Add a certificate signer for the token.
   * @param operator Address to set as a certificate signer.
   * @param authorized 'true' if operator shall be accepted as certificate signer, 'false' if not.
   */
  function setCertificateSigner(address operator, bool authorized) external onlyOwner {
    _setCertificateSigner(operator, authorized);
  }

  /**
   * @dev A test function
   * @param i An integer
   * @param data Certificate to control
   */
  function test(uint i, bytes b, bytes data)
    external
    isValidCertificate(data)
    returns (bool)
  {
    return (i >= 0 && b.length>0);
  }

  /**
   * @dev A test function
   * @param i An integer
   * @param data Certificate to control
   */
  function testCertificate(uint i, bytes b, bytes data)
    external
    returns (bool)
  {
    return((i >= 0 && b.length>0) && _checkCertificate(data, 0, 0x01ef73f0));
  }

}
