pragma solidity ^0.8.0;

import {ICertificateValidator} from "./ICertificateValidator.sol";
import {ERC20Extension} from "../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {CertificateLib, CertificateValidationType} from "./CertificateLib.sol";

contract CertificateValidatorExtension is ERC20Extension, ICertificateValidator {
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

    function initalize() external override {
        CertificateLib.addCertificateSigner(msg.sender);
    }

    function isCertificateSigner(address account) external override view returns (bool) {
        return CertificateLib.isCertificateSigner(account);
    }
    
    function addCertificateSigner(address account) external override onlyCertificateSigner {
        CertificateLib.addCertificateSigner(account);
    }

    function removeCertificateSigner(address account) external override onlyCertificateSigner {
        CertificateLib.removeCertificateSigner(account);
    }

    function usedCertificateNonce(address sender) external override view returns (uint256) {
        return CertificateLib.usedCertificateNonce(sender);
    }

    function usedCertificateSalt(bytes32 salt) external override view returns (bool) {
        return CertificateLib.usedCertificateSalt(salt);
    }

    function transferWithCertificate(address to, uint256 amount, bytes memory certificate) external override {

    }

    function transferFromWithCertificate(address from, address to, uint256 amount, bytes memory certificate) external override {

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