// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "./Roles.sol";


/**
 * @title CertificateSignerRole
 * @dev Certificate signers are responsible for signing certificates.
 */
abstract contract CertificateSignerRole {
    using Roles for Roles.Role;

    event CertificateSignerAdded(address indexed token, address indexed account);
    event CertificateSignerRemoved(address indexed token, address indexed account);

    // Mapping from token to token certificate signers.
    mapping(address => Roles.Role) private _certificateSigners;

    modifier onlyCertificateSigner(address token) virtual {
        require(isCertificateSigner(token, msg.sender));
        _;
    }

    function isCertificateSigner(address token, address account) public view returns (bool) {
        return _certificateSigners[token].has(account);
    }

    function addCertificateSigner(address token, address account) public onlyCertificateSigner(token) {
        _addCertificateSigner(token, account);
    }

    function removeCertificateSigner(address token, address account) public onlyCertificateSigner(token) {
        _removeCertificateSigner(token, account);
    }

    function renounceCertificateSigner(address token) public {
        _removeCertificateSigner(token, msg.sender);
    }

    function _addCertificateSigner(address token, address account) internal {
        _certificateSigners[token].add(account);
        emit CertificateSignerAdded(token, account);
    }

    function _removeCertificateSigner(address token, address account) internal {
        _certificateSigners[token].remove(account);
        emit CertificateSignerRemoved(token, account);
    }
}