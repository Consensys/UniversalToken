// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

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
abstract contract Extension is IExtensionTypes {
  function registerTokenSetup(
    address token,
    CertificateValidation certificateActivated,
    bool allowlistActivated,
    bool blocklistActivated,
    bool granularityByPartitionActivated,
    bool holdsActivated,
    address[] calldata operators
  ) external virtual;
}

contract ERC1400HoldableToken is ERC1400, IExtensionTypes {

  /**
   * @dev Initialize ERC1400 + setup the token extension.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param defaultPartitions Partitions chosen by default, when partition is
   * not specified, like the case ERC20 tranfers.
   * @param extension Address of token extension.
   * @param newOwner Address whom contract ownership shall be transferred to.
   */
  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    bytes32[] memory defaultPartitions,
    address extension,
    address newOwner
  )
    ERC1400(name, symbol, granularity, controllers, defaultPartitions)
  {
    if(extension != address(0)) {
      Extension(extension).registerTokenSetup(
        address(this), // token
        CertificateValidation.None, // certificateActivated
        true, // allowlistActivated
        true, // blocklistActivated
        true, // granularityByPartitionActivated
        true, // holdsActivated
        controllers // token controllers
      );

      _setTokenExtension(extension, ERC1400_TOKENS_VALIDATOR, true, true, true);
    }

    if(newOwner != address(0)) {
      transferOwnership(newOwner);
    }
  }

}