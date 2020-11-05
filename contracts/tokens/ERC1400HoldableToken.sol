pragma solidity ^0.5.0;

import "../ERC1400.sol";

/**
 * @notice Interface to the Minterrole contract
 */
interface IExtension {
  function registerTokenSetup(
    address token,
    bool allowlistActivated,
    bool blocklistActivated,
    bool granularityByPartitionActivated,
    bool holdsActivated,
    bool selfHoldsActivated,
    address[] calldata operators
  ) external;
}

contract ERC1400HoldableToken is ERC1400 {

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  /**
   * @dev Initialize ERC1400 + setup the token extension.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param defaultPartitions Partitions chosen by default, when partition is
   * not specified, like the case ERC20 tranfers.
   * @param extension Address of holdable token extension.
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
    public
    ERC1400(name, symbol, granularity, controllers, defaultPartitions)
  {
    if(extension != address(0)) {
      IExtension(extension).registerTokenSetup(address(this), true, true, true, true, false, controllers);

      _setTokenExtension(extension, ERC1400_TOKENS_VALIDATOR, true, true);
    }

    if(newOwner != address(0)) {
      _transferOwnership(newOwner);
    }
  }

}