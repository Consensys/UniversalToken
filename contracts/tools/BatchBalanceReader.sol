// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interface/ERC1820Implementer.sol";

import "../IERC1400.sol";

interface IERC1400Extended {
    // Not a real interface but added here since 'totalSupplyByPartition' doesn't belong to IERC1400

    function totalSupplyByPartition(bytes32 partition)
        external
        view
        returns (uint256);
}

/**
 * @title BatchBalanceReader
 * @dev Proxy contract to read multiple ERC1400/ERC20 token balances in a single contract call.
 */
contract BatchBalanceReader is ERC1820Implementer {
    string internal constant BALANCE_READER = "BatchBalanceReader";

    constructor() {
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
    ) external view returns (uint256[] memory) {
        uint256[] memory partitionBalances = new uint256[](
            tokenAddresses.length * partitions.length * tokenHolders.length
        );
        uint256 index;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            for (uint256 j = 0; j < tokenAddresses.length; j++) {
                for (uint256 k = 0; k < partitions.length; k++) {
                    index =
                        i *
                        (tokenAddresses.length * partitions.length) +
                        j *
                        partitions.length +
                        k;
                    partitionBalances[index] = IERC1400(tokenAddresses[j])
                        .balanceOfByPartition(partitions[k], tokenHolders[i]);
                }
            }
        }

        return partitionBalances;
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
    ) external view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](
            tokenHolders.length * tokenAddresses.length
        );
        uint256 index;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            for (uint256 j = 0; j < tokenAddresses.length; j++) {
                index = i * tokenAddresses.length + j;
                balances[index] = IERC20(tokenAddresses[j]).balanceOf(
                    tokenHolders[i]
                );
            }
        }
        return balances;
    }

    /**
     * @dev Get a batch of ERC1400 token total supplies by partitions.
     * @param partitions Name of the partitions.
     * @param tokenAddresses Addresses of tokens where the balances need to be fetched.
     * @return Balances array.
     */
    function totalSuppliesByPartition(
        bytes32[] calldata partitions,
        address[] calldata tokenAddresses
    ) external view returns (uint256[] memory) {
        uint256[] memory partitionSupplies = new uint256[](
            partitions.length * tokenAddresses.length
        );
        uint256 index;
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            for (uint256 j = 0; j < partitions.length; j++) {
                index = i * partitions.length + j;
                partitionSupplies[index] = IERC1400Extended(tokenAddresses[i])
                    .totalSupplyByPartition(partitions[j]);
            }
        }
        return partitionSupplies;
    }

    /**
     * @dev Get a batch of ERC20 token total supplies.
     * @param tokenAddresses Addresses of tokens where the balances need to be fetched.
     * @return Balances array.
     */
    function totalSupplies(address[] calldata tokenAddresses)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory supplies = new uint256[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            supplies[i] = IERC20(tokenAddresses[i]).totalSupply();
        }
        return supplies;
    }
}
