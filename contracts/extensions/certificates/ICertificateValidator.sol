pragma solidity ^0.8.0;

interface ICertificateValidator {
    event CertificateSignerAdded(address indexed account);
    event CertificateSignerRemoved(address indexed account);

    function isCertificateSigner(address account) external view returns (bool);
    
    function addCertificateSigner(address account) external;

    function removeCertificateSigner(address account) external;

    function usedCertificateNonce(address sender) external view returns (uint256);

    function usedCertificateSalt(bytes32 salt) external view returns (bool);
}