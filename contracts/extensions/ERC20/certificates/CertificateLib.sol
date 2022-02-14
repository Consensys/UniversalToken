pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Roles} from "../../../roles/Roles.sol";
import {DomainAware} from "../../../tools/DomainAware.sol";

enum CertificateValidationType {
    None,
    NonceBased,
    SaltBased
}

library CertificateLib {
    using SafeMath for uint256;

    using Roles for Roles.Role;

    bytes32 constant CERTIFICATE_DATA_SLOT = keccak256("certificates.data");
    bytes32 constant CERTIFICATE_SIGNER_ROLE = keccak256("certificates.roles.certificatesigner");

    struct CertificateData {
        // Mapping from (token, certificateNonce) to "used" status to ensure a certificate can be used only once
        mapping(address => uint256) _usedCertificateNonce;

        // Mapping from (token, certificateSalt) to "used" status to ensure a certificate can be used only once
        mapping(bytes32 => bool) _usedCertificateSalt;

        CertificateValidationType _certificateType;
    }

    function certificateData() internal pure returns (CertificateData storage ds) {
        bytes32 position = CERTIFICATE_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function isCertificateSigner(address account) internal view returns (bool) {
        return Roles.roleStorage(CERTIFICATE_SIGNER_ROLE).has(account);
    }

    function usedCertificateNonce(address sender) internal view returns (uint256) {
        return certificateData()._usedCertificateNonce[sender];
    }

    function usedCertificateSalt(bytes32 salt) internal view returns (bool) {
        return certificateData()._usedCertificateSalt[salt];
    }

    function certificateValidationType() internal view returns (CertificateValidationType) {
        return certificateData()._certificateType;
    }

    /**
    * @dev Checks if a nonce-based certificate is correct
    * @param certificate Certificate to control
    */
    function _checkNonceBasedCertificate(address token, address msgSender, bytes memory payloadWithCertificate,bytes memory certificate) internal view returns(bool) {
        // Certificate should be 97 bytes long
        if (certificate.length != 97) {
            return false;
        }

        uint256 e;
        uint8 v;

        // Extract certificate information and expiration time from payload
        assembly {
            // Retrieve expirationTime & ECDSA element (v) from certificate which is a 97 long bytes
            // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
            e := mload(add(certificate, 0x20))
            v := byte(0, mload(add(certificate, 0x80)))
        }

        // Certificate should not be expired
        if (e < block.timestamp) {
            return false;
        }

        if (v < 27) {
            v += 27;
        }

        // Perform ecrecover to ensure message information corresponds to certificate
        if (v == 27 || v == 28) {
            // Extract certificate from payload
            bytes memory payloadWithoutCertificate = new bytes(payloadWithCertificate.length.sub(160));
            for (uint i = 0; i < payloadWithCertificate.length.sub(160); i++) { // replace 4 bytes corresponding to function selector
                payloadWithoutCertificate[i] = payloadWithCertificate[i];
            }

            // Pack and hash
            bytes memory pack = abi.encodePacked(
                msgSender,
                token,
                payloadWithoutCertificate,
                e,
                certificateData()._usedCertificateNonce[msgSender]
            );
            bytes32 hash = keccak256(
                abi.encodePacked(
                    DomainAware(token).generateDomainSeparator(),
                    keccak256(pack)
                )
            );

            bytes32 r;
            bytes32 s;
            // Extract certificate information and expiration time from payload
            assembly {
                // Retrieve ECDSA elements (r, s) from certificate which is a 97 long bytes
                // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
                r := mload(add(certificate, 0x40))
                s := mload(add(certificate, 0x60))
            }

            // Check if certificate match expected transactions parameters
            if (isCertificateSigner(ecrecover(hash, v, r, s))) {
                return true;
            }
        }
        return false;
    }

    /**
    * @dev Checks if a salt-based certificate is correct
    * @param certificate Certificate to control
    */
    function _checkSaltBasedCertificate(address token, address msgSender, bytes memory payloadWithCertificate, bytes memory certificate) internal view returns(bool, bytes32) {
        // Certificate should be 129 bytes long
        if (certificate.length != 129) {
            return (false, "");
        }

        bytes32 salt;
        uint256 e;
        uint8 v;

        // Extract certificate information and expiration time from payload
        assembly {
            // Retrieve expirationTime & ECDSA elements from certificate which is a 97 long bytes
            // Certificate encoding format is: <salt (32 bytes)>@<expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
            salt := mload(add(certificate, 0x20))
            e := mload(add(certificate, 0x40))
            v := byte(0, mload(add(certificate, 0xa0)))
        }

        // Certificate should not be expired
        if (e < block.timestamp) {
            return (false, "");
        }

        if (v < 27) {
            v += 27;
        }

        // Perform ecrecover to ensure message information corresponds to certificate
        if (v == 27 || v == 28) {
            // Extract certificate from payload
            bytes memory payloadWithoutCertificate = new bytes(payloadWithCertificate.length.sub(192));
            for (uint i = 0; i < payloadWithCertificate.length.sub(192); i++) { // replace 4 bytes corresponding to function selector
                payloadWithoutCertificate[i] = payloadWithCertificate[i];
            }

            // Pack and hash
            bytes memory pack = abi.encodePacked(
                msgSender,
                token,
                payloadWithoutCertificate,
                e,
                salt
            );

            bytes32 hash = keccak256(
                abi.encodePacked(
                    DomainAware(token).generateDomainSeparator(),
                    keccak256(pack)
                )
            );

            bytes32 r;
            bytes32 s;
            // Extract certificate information and expiration time from payload
            assembly {
                // Retrieve ECDSA elements (r, s) from certificate which is a 97 long bytes
                // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
                r := mload(add(certificate, 0x60))
                s := mload(add(certificate, 0x80))
            }

            // Check if certificate match expected transactions parameters
            if (isCertificateSigner(ecrecover(hash, v, r, s)) && !certificateData()._usedCertificateSalt[salt]) {
                return (true, salt);
            }
        }
        return (false, "");
    }
}