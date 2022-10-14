// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interface/ERC1820Implementer.sol";

import "../IERC1400.sol";

/**
 * @notice Interface to the Minterrole contract
 */
interface IMinterRole {
  function isMinter(address account) external view returns (bool);
}

/**
 * @title BatchTokenIssuer
 * @dev Proxy contract to issue multiple ERC1400/ERC20 tokens in a single transaction.
 */
contract BatchTokenIssuer is ERC1820Implementer {

  string constant internal BATCH_ISSUER = "BatchTokenIssuer";

  // Mapping from token to token minters.
  mapping(address => address[]) internal _tokenMinters;

  // Mapping from (token, operator) to token minter status.
  mapping(address => mapping(address => bool)) internal _isTokenMinter;

  /**
   * @dev Modifier to verify if sender is a token minter.
   */
  modifier onlyTokenMinter(address token) {
    require(IMinterRole(token).isMinter(msg.sender),
      "Sender is not a token minter."
    );
    _;
  }

  constructor() {
    ERC1820Implementer._setInterface(BATCH_ISSUER);
  }

  /**
   * @dev Issue tokens for multiple addresses.
   * @param token Address of token where the tokens need to be issued.
   * @param partitions Name of the partitions.
   * @param tokenHolders Addresses for which we want to issue tokens.
   * @param values Number of tokens issued.
   */
  function batchIssueByPartition(
    address token,
    bytes32[] calldata partitions,
    address[] calldata tokenHolders,
    uint256[] calldata values
  )
    external
    onlyTokenMinter(token)
  {
    require(partitions.length == tokenHolders.length, "partitions and tokenHolders arrays have different lengths");
    require(partitions.length == values.length, "partitions and values arrays have different lengths");
    
    for (uint i = 0; i < partitions.length; i++) {
        IERC1400(token).issueByPartition(partitions[i], tokenHolders[i], values[i], "");
    }
  }

}
