pragma solidity ^0.5.0;

import "../CertificateController/CertificateControllerNonce.sol";

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @title ControlledMock
 * @dev Mock class to test certificate controller
 */
contract ControlledMock is Ownable, CertificateController {

  constructor(address certificateSigner)
    public
    CertificateController(certificateSigner, true)
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
   * @dev Activate/disactivate certificate controller.
   * @param activated 'true', if the certificate control shall be activated, 'false' if not.
   */
  function setCertificateControllerActivated(bool activated) external onlyOwner {
   _setCertificateControllerActivated(activated);
  }

  /**
   * @dev A test function
   * @param i An integer
   * @param data Certificate to control
   */
  function test(uint i, bytes memory b, bytes memory data)
    internal
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
  function testCertificate(uint i, bytes calldata b, bytes calldata data)
    view
    external
    returns (bool)
  {
    return((i >= 0 && b.length>0) && _checkCertificate(data, 0, 0x01ef73f0));
  }

}
