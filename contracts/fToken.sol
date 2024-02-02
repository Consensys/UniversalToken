// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "./ERC1400.sol";

contract fToken is ERC1400{
    
  using SafeMath for uint256;


  /**
   * @dev Initialize ERC1400 + register the contract implementation in ERC1820Registry.
   * @param tokenName Name of the token.
   * @param tokenSymbol Symbol of the token.
   * @param tokenGranularity Granularity of the token.
   * @param initialControllers Array of initial controllers.
   * @param defaultPartitions Partitions chosen by default, when partition is
   * not specified, like the case ERC20 tranfers.
   */
  constructor(
    string memory tokenName,
    string memory tokenSymbol,
    uint256 tokenGranularity,
    address[] memory initialControllers,
    bytes32[] memory defaultPartitions
  ) ERC1400(tokenName, tokenSymbol, tokenGranularity, initialControllers, defaultPartitions) {

  }

}
