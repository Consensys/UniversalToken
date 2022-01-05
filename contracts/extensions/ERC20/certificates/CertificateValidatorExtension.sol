pragma solidity ^0.8.0;

import {ICertificateValidator} from "./ICertificateValidator.sol";
import {ERC20Extension} from "../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {CertificateLib, CertificateValidationType} from "./CertificateLib.sol";

contract CertificateValidatorExtension is ERC20Extension, ICertificateValidator {
    
    bytes32 constant CERTIFICATE_SIGNER_ROLE = keccak256("certificates.roles.certificatesigner");

    constructor() {
        _registerFunction(CertificateValidatorExtension.addCertificateSigner.selector);
        _registerFunction(CertificateValidatorExtension.removeCertificateSigner.selector);
        _registerFunction(CertificateValidatorExtension.transferWithCertificate.selector);
        _registerFunction(CertificateValidatorExtension.transferFromWithCertificate.selector);

        _registerFunctionName('isCertificateSigner(address)');
        _registerFunctionName('usedCertificateNonce(address)');
        _registerFunctionName('usedCertificateSalt(bytes32)');

        _supportInterface(type(ICertificateValidator).interfaceId);
    }

    modifier onlyCertificateSigner {
        require(hasRole(_msgSender(), CERTIFICATE_SIGNER_ROLE), "Only certificate signers");
        _;
    }

    function initalize() external override {
        _addRole(_msgSender(), CERTIFICATE_SIGNER_ROLE);
    }

    function isCertificateSigner(address account) external override view returns (bool) {
        return hasRole(account, CERTIFICATE_SIGNER_ROLE);
    }
    
    function addCertificateSigner(address account) external override onlyCertificateSigner {
        _addRole(account, CERTIFICATE_SIGNER_ROLE);
    }

    function removeCertificateSigner(address account) external override onlyCertificateSigner {
        _removeRole(account, CERTIFICATE_SIGNER_ROLE);
    }

    function usedCertificateNonce(address sender) external override view returns (uint256) {
        return CertificateLib.usedCertificateNonce(sender);
    }

    function usedCertificateSalt(bytes32 salt) external override view returns (bool) {
        return CertificateLib.usedCertificateSalt(salt);
    }

    function transferWithCertificate(address to, uint256 amount, bytes memory certificate) external override {
        address from = msg.sender;
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            from, //TODO who is the operator?
            from,
            to,
            amount,
            certificate,
            ""
        );

        require(_transfer(data), "Transfer failed");
    }

    function transferFromWithCertificate(address from, address to, uint256 amount, bytes memory certificate) external override {
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            msg.sender,
            from,
            to,
            amount,
            certificate,
            ""
        );

        require(_transfer(data), "Transfer failed");
    }

    function validateTransfer(TransferData memory data) external override view returns (bool) {
        require(data.data.length > 0, "Data cannot be empty");

        CertificateValidationType validationType = CertificateLib.certificateData()._certificateType;

        require(validationType > CertificateValidationType.None, "Validation mode not set");

        bool valid = false;
        if (validationType == CertificateValidationType.NonceBased) {
            valid = CertificateLib._checkNonceBasedCertificate(address(this), data.operator, data.payload, data.data);
        } else if (validationType == CertificateValidationType.SaltBased) {
            bytes32 salt;
            (valid, salt) = CertificateLib._checkSaltBasedCertificate(address(this), data.operator, data.payload, data.data);
        }

        require(valid, "Certificate not valid");

        return true;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        require(data.data.length > 0, "Data cannot be empty");

        CertificateValidationType validationType = CertificateLib.certificateData()._certificateType;

        require(validationType > CertificateValidationType.None, "Validation mode not set");

        bool valid = false;
        if (validationType == CertificateValidationType.NonceBased) {
            valid = CertificateLib._checkNonceBasedCertificate(address(this), data.operator, data.payload, data.data);

            CertificateLib.certificateData()._usedCertificateNonce[data.operator]++;
        } else if (validationType == CertificateValidationType.SaltBased) {
            bytes32 salt;
            (valid, salt) = CertificateLib._checkSaltBasedCertificate(address(this), data.operator, data.payload, data.data);

            CertificateLib.certificateData()._usedCertificateSalt[salt] = true;
        }

        require(valid, "Certificate not valid");

        return true;
    }
}