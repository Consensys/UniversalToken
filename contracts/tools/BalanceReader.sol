pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../token/ERC1400Partition/IERC1400Partition.sol";

import "../token/ERC1820/ERC1820Implementer.sol";

/**
 * @title BalanceReader
 * @dev Proxy contract to read multiple ERC1400/ERC20 token balances in a single contract call.
 */
contract BalanceReader is ERC1820Implementer {

  string constant internal BALANCE_READER = "BalanceReader";

  constructor() public {
    ERC1820Implementer._setInterface(BALANCE_READER);
  }

  /**
   * @dev Get a batch of ERC1400 token balances.
   * @param tokenHolders Addresses for which the balance is required.
   * @param tokenAddresses Addresses of tokens where the balances need to be fetched.
   * @param partitions Name of the partitions.
   * @return Balances array.
   */
  function balancesOfByPartition(
    address[] calldata tokenHolders,
    address[] calldata tokenAddresses,
    bytes32[] calldata partitions
  )
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory balances = new uint256[](tokenAddresses.length * partitions.length * tokenHolders.length);
    uint256 index;
    for (uint i = 0; i < tokenHolders.length; i++) {
        for (uint j = 0; j < tokenAddresses.length; j++) {
            for (uint k = 0; k < partitions.length; k++) {
                    index = i * (tokenAddresses.length * partitions.length) + j * partitions.length + k;
                    balances[index] = IERC1400Partition(tokenAddresses[j]).balanceOfByPartition(partitions[k], tokenHolders[i]);
            }
        }
    }

    return balances;
  }

  /**
   * @dev Get a batch of ERC20 token balances.
   * @param tokenHolders Addresses for which the balance is required.
   * @param tokenAddresses Addresses of tokens where the balances need to be fetched.
   * @return Balances array.
   */
  function balancesOf(
    address[] calldata tokenHolders,
    address[] calldata tokenAddresses
  )
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory balances = new uint256[](tokenHolders.length * tokenAddresses.length);
    uint256 index;
    for (uint i = 0; i < tokenHolders.length; i++) {
      for (uint j = 0; j < tokenAddresses.length; j++) {
        index = i * tokenAddresses.length + j;
        balances[index] = IERC20(tokenAddresses[j]).balanceOf(tokenHolders[i]);
      }
    }
    return balances;
  }
}
