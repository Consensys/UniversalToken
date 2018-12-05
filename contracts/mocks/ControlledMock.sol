pragma solidity ^0.4.24;

import "../CertificateController.sol";


/**
 * @title ControlledMock
 * @dev Mock class to test certificate controller
 */
contract ControlledMock is CertificateController {

    constructor(
        address _certificateSigner
    )
        public
        CertificateController(_certificateSigner)
    {}

    /**
     * @dev A test function
     * @param i An integer
     * @param data Certificate to control
     */
    function test(uint i, bytes b, bytes data)
        public
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
        public
        payable
        returns (bool)
    {
      return((i >= 0 && b.length>0) && _checkCertificate(data, 0, 0x01ef73f0));
    }
}
