/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "../ERC1400.sol";

/**
 * @notice Interface to the extension types
 */
interface IExtensionTypes {
  enum CertificateValidation {
    None,
    NonceBased,
    SaltBased
  }
}

/**
 * @notice Interface to the extension contract
 */
contract Extension is IExtensionTypes {
  function registerTokenSetup(
    address token,
    CertificateValidation certificateActivated,
    bool allowlistActivated,
    bool blocklistActivated,
    bool granularityByPartitionActivated,
    bool holdsActivated,
    bool selfHoldsActivated,
    address[] calldata operators
  ) external;

  function addCertificateSigner(
    address token,
    address account
  ) external;
}


/**
 * @title ERC1400HoldableCertificateNonceToken
 * @dev Holdable ERC1400 with nonce-based certificate controller logic
 */
contract ERC1400HoldableCertificateToken is ERC1400, IExtensionTypes {

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  /**
   * @dev Initialize ERC1400 + initialize certificate controller.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param defaultPartitions Partitions chosen by default, when partition is
   * not specified, like the case ERC20 tranfers.
   * @param extension Address of token extension.
   * @param newOwner Address whom contract ownership shall be transferred to.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, issuance,
   * redemption (Cf. CertificateController.sol).
   * @param certificateActivated If set to 'true', the certificate controller
   * is activated at contract creation.
   */
  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    bytes32[] memory defaultPartitions,
    address extension,
    address newOwner,
    address certificateSigner,
    CertificateValidation certificateActivated
  )
    public
    ERC1400(name, symbol, granularity, controllers, defaultPartitions)
  {
    if(extension != address(0)) {
      Extension(extension).registerTokenSetup(
        address(this), // token
        certificateActivated, // certificateActivated
        true, // allowlistActivated
        true, // blocklistActivated
        true, // granularityByPartitionActivated
        true, // holdsActivated
        false, // selfHoldsActivated
        controllers // token controllers
      );

      if(certificateSigner != address(0)) {
        Extension(extension).addCertificateSigner(address(this), certificateSigner);
      }

      _setTokenExtension(extension, ERC1400_TOKENS_VALIDATOR, true, true);
    }

    if(newOwner != address(0)) {
      _transferOwnership(newOwner);
    }
  }

}