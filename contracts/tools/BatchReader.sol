// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC1820Client.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";


import "../interface/ERC1820Implementer.sol";

import "../IERC1400.sol";

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

interface IERC1400Extended {
    // Not a real interface but added here for functions which don't belong to IERC1400

    function owner() external view returns (address);

    function controllers() external view returns (address[] memory);

    function totalPartitions() external view returns (bytes32[] memory);

    function getDefaultPartitions() external view returns (bytes32[] memory);

    function totalSupplyByPartition(bytes32 partition) external view returns (uint256);
}

abstract contract IERC1400TokensValidatorExtended is IExtensionTypes {
    // Not a real interface but added here for functions which don't belong to IERC1400TokensValidator

    function retrieveTokenSetup(address token) external virtual view returns (CertificateValidation, bool, bool, bool, bool, address[] memory);

    function spendableBalanceOfByPartition(address token, bytes32 partition, address account) external virtual view returns (uint256);

    function isAllowlisted(address token, address account) public virtual view returns (bool);

    function isBlocklisted(address token, address account) public virtual view returns (bool);
}

/**
 * @title BatchReader
 * @dev Proxy contract to read multiple information from the smart contract in a single contract call.
 */
contract BatchReader is IExtensionTypes, ERC1820Client, ERC1820Implementer {
    using SafeMath for uint256;

    string internal constant BALANCE_READER = "BatchReader";

    string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

    // Mapping from token to token extension address
    mapping(address => address) internal _extension;

    constructor() {
        ERC1820Implementer._setInterface(BALANCE_READER);
    }

    /**
     * @dev Get batch of token supplies.
     * @return Batch of token supplies.
     */
    function batchTokenSuppliesInfos(address[] calldata tokens) external view returns (uint256[] memory, uint256[] memory, bytes32[] memory, uint256[] memory, uint256[] memory, bytes32[] memory) {
        uint256[] memory batchTotalSupplies = new uint256[](tokens.length);
        for (uint256 j = 0; j < tokens.length; j++) {
            batchTotalSupplies[j] = IERC20(tokens[j]).totalSupply();
        }

        (uint256[] memory totalPartitionsLengths, bytes32[] memory batchTotalPartitions_, uint256[] memory batchPartitionSupplies) = batchTotalPartitions(tokens);

        (uint256[] memory defaultPartitionsLengths, bytes32[] memory batchDefaultPartitions_) = batchDefaultPartitions(tokens);

        return (batchTotalSupplies, totalPartitionsLengths, batchTotalPartitions_, batchPartitionSupplies, defaultPartitionsLengths, batchDefaultPartitions_);
    }

    /**
     * @dev Get batch of token roles.
     * @return Batch of token roles.
     */
    function batchTokenRolesInfos(address[] calldata tokens) external view returns (address[] memory, uint256[] memory, address[] memory, uint256[] memory, address[] memory) {
        (uint256[] memory batchExtensionControllersLength, address[] memory batchExtensionControllers_) = batchExtensionControllers(tokens);

        (uint256[] memory batchControllersLength, address[] memory batchControllers_) = batchControllers(tokens);

        address[] memory batchOwners = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            batchOwners[i] = IERC1400Extended(tokens[i]).owner();
        }
        return (batchOwners, batchControllersLength, batchControllers_, batchExtensionControllersLength, batchExtensionControllers_);
    }

    /**
     * @dev Get batch of token controllers.
     * @return Batch of token controllers.
     */
    function batchControllers(address[] memory tokens) public view returns (uint256[] memory, address[] memory) {
        uint256[] memory batchControllersLength = new uint256[](tokens.length);
        uint256 controllersLength=0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address[] memory controllers = IERC1400Extended(tokens[i]).controllers();
            batchControllersLength[i] = controllers.length;
            controllersLength = controllersLength.add(controllers.length);
        }

        address[] memory batchControllersResponse = new address[](controllersLength);

        uint256 counter = 0;
        for (uint256 j = 0; j < tokens.length; j++) {
            address[] memory controllers = IERC1400Extended(tokens[j]).controllers();

            for (uint256 k = 0; k < controllers.length; k++) {
                batchControllersResponse[counter] = controllers[k];
                counter++;
            }
        }

        return (batchControllersLength, batchControllersResponse);
    }

    /**
     * @dev Get batch of token extension controllers.
     * @return Batch of token extension controllers.
     */
    function batchExtensionControllers(address[] memory tokens) public view returns (uint256[] memory, address[] memory) {
        address[] memory batchTokenExtension = new address[](tokens.length);

        uint256[] memory batchExtensionControllersLength = new uint256[](tokens.length);
        uint256 extensionControllersLength=0;

        for (uint256 i = 0; i < tokens.length; i++) {
            batchTokenExtension[i] = interfaceAddr(tokens[i], ERC1400_TOKENS_VALIDATOR);

            if (batchTokenExtension[i] != address(0)) {
                (,,,,,address[] memory extensionControllers) = IERC1400TokensValidatorExtended(batchTokenExtension[i]).retrieveTokenSetup(tokens[i]);
                batchExtensionControllersLength[i] = extensionControllers.length;
                extensionControllersLength = extensionControllersLength.add(extensionControllers.length);
            } else {
                batchExtensionControllersLength[i] = 0;
            }
        }

        address[] memory batchExtensionControllersResponse = new address[](extensionControllersLength);

        uint256 counter = 0;
        for (uint256 j = 0; j < tokens.length; j++) {
            if (batchTokenExtension[j] != address(0)) {
                (,,,,,address[] memory extensionControllers) = IERC1400TokensValidatorExtended(batchTokenExtension[j]).retrieveTokenSetup(tokens[j]);

                for (uint256 k = 0; k < extensionControllers.length; k++) {
                    batchExtensionControllersResponse[counter] = extensionControllers[k];
                    counter++;
                }
            }
        }

        return (batchExtensionControllersLength, batchExtensionControllersResponse);
    }

    /**
     * @dev Get batch of token extension setup.
     * @return Batch of token extension setup.
     */
    function batchTokenExtensionSetup(address[] calldata tokens) external view returns (address[] memory, CertificateValidation[] memory, bool[] memory, bool[] memory, bool[] memory, bool[] memory) {
        (address[] memory batchTokenExtension, CertificateValidation[] memory batchCertificateActivated, bool[] memory batchAllowlistActivated, bool[] memory batchBlocklistActivated) = batchTokenExtensionSetup1(tokens);

        (bool[] memory batchGranularityByPartitionActivated, bool[] memory batchHoldsActivated) = batchTokenExtensionSetup2(tokens);
        return (batchTokenExtension, batchCertificateActivated, batchAllowlistActivated, batchBlocklistActivated, batchGranularityByPartitionActivated, batchHoldsActivated);
    }

    /**
     * @dev Get batch of token extension setup (part 1).
     * @return Batch of token extension setup (part 1).
     */
    function batchTokenExtensionSetup1(address[] memory tokens) public view returns (address[] memory, CertificateValidation[] memory, bool[] memory, bool[] memory) {
        address[] memory batchTokenExtension = new address[](tokens.length);
        CertificateValidation[] memory batchCertificateActivated = new CertificateValidation[](tokens.length);
        bool[] memory batchAllowlistActivated = new bool[](tokens.length);
        bool[] memory batchBlocklistActivated = new bool[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            batchTokenExtension[i] = interfaceAddr(tokens[i], ERC1400_TOKENS_VALIDATOR);

            if (batchTokenExtension[i] != address(0)) {
                (CertificateValidation certificateActivated, bool allowlistActivated, bool blocklistActivated,,,) = IERC1400TokensValidatorExtended(batchTokenExtension[i]).retrieveTokenSetup(tokens[i]);
                batchCertificateActivated[i] = certificateActivated;
                batchAllowlistActivated[i] = allowlistActivated;
                batchBlocklistActivated[i] = blocklistActivated;
            } else {
                batchCertificateActivated[i] = CertificateValidation.None;
                batchAllowlistActivated[i] = false;
                batchBlocklistActivated[i] = false;
            }
        }

        return (batchTokenExtension, batchCertificateActivated, batchAllowlistActivated, batchBlocklistActivated);
    }

    /**
     * @dev Get batch of token extension setup (part 2).
     * @return Batch of token extension setup (part 2).
     */
    function batchTokenExtensionSetup2(address[] memory tokens) public view returns (bool[] memory, bool[] memory) {
        address[] memory batchTokenExtension = new address[](tokens.length);
        bool[] memory batchGranularityByPartitionActivated = new bool[](tokens.length);
        bool[] memory batchHoldsActivated = new bool[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            batchTokenExtension[i] = interfaceAddr(tokens[i], ERC1400_TOKENS_VALIDATOR);

            if (batchTokenExtension[i] != address(0)) {
                (,,, bool granularityByPartitionActivated, bool holdsActivated,) = IERC1400TokensValidatorExtended(batchTokenExtension[i]).retrieveTokenSetup(tokens[i]);
                batchGranularityByPartitionActivated[i] = granularityByPartitionActivated;
                batchHoldsActivated[i] = holdsActivated;
            } else {
                batchGranularityByPartitionActivated[i] = false;
                batchHoldsActivated[i] = false;
            }
        }

        return (batchGranularityByPartitionActivated, batchHoldsActivated);
    }

    /**
     * @dev Get batch of ERC1400 balances.
     * @return Batch of ERC1400 balances.
     */
    function batchERC1400Balances(address[] calldata tokens, address[] calldata tokenHolders) external view returns (uint256[] memory, uint256[] memory, uint256[] memory, bytes32[] memory, uint256[] memory, uint256[] memory) {
        (,, uint256[] memory batchSpendableBalancesOfByPartition) = batchSpendableBalanceOfByPartition(tokens, tokenHolders);

        (uint256[] memory totalPartitionsLengths, bytes32[] memory batchTotalPartitions_, uint256[] memory batchBalancesOfByPartition) = batchBalanceOfByPartition(tokens, tokenHolders);

        uint256[] memory batchBalancesOf = batchBalanceOf(tokens, tokenHolders);

        uint256[] memory batchEthBalances = batchEthBalance(tokenHolders);

        return (batchEthBalances, batchBalancesOf, totalPartitionsLengths, batchTotalPartitions_, batchBalancesOfByPartition, batchSpendableBalancesOfByPartition);
    }

    /**
     * @dev Get batch of ERC20 balances.
     * @return Batch of ERC20 balances.
     */
    function batchERC20Balances(address[] calldata tokens, address[] calldata tokenHolders) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory batchBalancesOf = batchBalanceOf(tokens, tokenHolders);

        uint256[] memory batchEthBalances = batchEthBalance(tokenHolders);

        return (batchEthBalances, batchBalancesOf);
    }

    /**
     * @dev Get batch of ETH balances.
     * @return Batch of token ETH balances.
     */
    function batchEthBalance(address[] memory tokenHolders) public view returns (uint256[] memory) {
        uint256[] memory batchEthBalanceResponse = new uint256[](tokenHolders.length);

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            batchEthBalanceResponse[i] = tokenHolders[i].balance;
        }

        return batchEthBalanceResponse;
    }

    /**
     * @dev Get batch of ERC721 balances.
     * @return Batch of ERC721 balances.
     */
    function batchERC721Balances(address[] calldata tokens, address[] calldata tokenHolders) external view returns (uint256[] memory, uint256[][][] memory) {
        uint256[][][] memory batchBalanceOfResponse = new uint256[][][](tokens.length);

        for (uint256 j = 0; j < tokens.length; j++) {
            IERC721Enumerable token = IERC721Enumerable(tokens[j]);
            uint256[][] memory batchBalance = new uint256[][](tokenHolders.length);
            
            for (uint256 i = 0; i < tokenHolders.length; i++) {
                address holder = tokenHolders[i];
                uint256 tokenCount = token.balanceOf(holder);

                uint256[] memory balance = new uint256[](tokenCount);

                for (uint256 k = 0; k < tokenCount; k++) {
                    balance[k] = token.tokenOfOwnerByIndex(holder, k);
                }

                batchBalance[i] = balance;
            }

            batchBalanceOfResponse[j] = batchBalance;
        }

        uint256[] memory batchEthBalances = batchEthBalance(tokenHolders);

        return (batchEthBalances, batchBalanceOfResponse);
    }

    /**
     * @dev Get batch of token balances.
     * @return Batch of token balances.
     */
    function batchBalanceOf(address[] memory tokens, address[] memory tokenHolders) public view returns (uint256[] memory) {
        uint256[] memory batchBalanceOfResponse = new uint256[](tokenHolders.length * tokens.length);

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                batchBalanceOfResponse[i*tokens.length + j] = IERC20(tokens[j]).balanceOf(tokenHolders[i]);
            }
        }

        return batchBalanceOfResponse;
    }

    /**
     * @dev Get batch of partition balances.
     * @return Batch of token partition balances.
     */
    function batchBalanceOfByPartition(address[] memory tokens, address[] memory tokenHolders) public view returns (uint256[] memory, bytes32[] memory, uint256[] memory) {
        (uint256[] memory totalPartitionsLengths, bytes32[] memory batchTotalPartitions_,) = batchTotalPartitions(tokens);
        
        uint256[] memory batchBalanceOfByPartitionResponse = new uint256[](tokenHolders.length * batchTotalPartitions_.length);

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            uint256 counter = 0;
            for (uint256 j = 0; j < tokens.length; j++) {
                for (uint256 k = 0; k < totalPartitionsLengths[j]; k++) {
                    batchBalanceOfByPartitionResponse[i*batchTotalPartitions_.length + counter] = IERC1400(tokens[j]).balanceOfByPartition(batchTotalPartitions_[counter], tokenHolders[i]);
                    counter++;
                }
            }
        }

        return (totalPartitionsLengths, batchTotalPartitions_, batchBalanceOfByPartitionResponse);
    }

    /**
     * @dev Get batch of spendable partition balances.
     * @return Batch of token spendable partition balances.
     */
    function batchSpendableBalanceOfByPartition(address[] memory tokens, address[] memory tokenHolders) public view returns (uint256[] memory, bytes32[] memory, uint256[] memory) {
        (uint256[] memory totalPartitionsLengths, bytes32[] memory batchTotalPartitions_,) = batchTotalPartitions(tokens);
        
        uint256[] memory batchSpendableBalanceOfByPartitionResponse = new uint256[](tokenHolders.length * batchTotalPartitions_.length);

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            uint256 counter = 0;
            for (uint256 j = 0; j < tokens.length; j++) {
                address tokenExtension = interfaceAddr(tokens[j], ERC1400_TOKENS_VALIDATOR);

                for (uint256 k = 0; k < totalPartitionsLengths[j]; k++) {
                    if (tokenExtension != address(0)) {
                        batchSpendableBalanceOfByPartitionResponse[i*batchTotalPartitions_.length + counter] = IERC1400TokensValidatorExtended(tokenExtension).spendableBalanceOfByPartition(tokens[j], batchTotalPartitions_[counter], tokenHolders[i]);
                    } else {
                        batchSpendableBalanceOfByPartitionResponse[i*batchTotalPartitions_.length + counter] = IERC1400(tokens[j]).balanceOfByPartition(batchTotalPartitions_[counter], tokenHolders[i]);
                    }
                    counter++;
                }
            }
        }

        return (totalPartitionsLengths, batchTotalPartitions_, batchSpendableBalanceOfByPartitionResponse);
    }

    /**
     * @dev Get batch of token partitions.
     * @return Batch of token partitions.
     */
    function batchTotalPartitions(address[] memory tokens) public view returns (uint256[] memory, bytes32[] memory, uint256[] memory) {
        uint256[] memory batchTotalPartitionsLength = new uint256[](tokens.length);
        uint256 totalPartitionsLength=0;

        for (uint256 i = 0; i < tokens.length; i++) {
            bytes32[] memory totalPartitions = IERC1400Extended(tokens[i]).totalPartitions();
            batchTotalPartitionsLength[i] = totalPartitions.length;
            totalPartitionsLength = totalPartitionsLength.add(totalPartitions.length);
        }

        bytes32[] memory batchTotalPartitionsResponse = new bytes32[](totalPartitionsLength);
        uint256[] memory batchPartitionSupplies = new uint256[](totalPartitionsLength);

        uint256 counter = 0;
        for (uint256 j = 0; j < tokens.length; j++) {
            bytes32[] memory totalPartitions = IERC1400Extended(tokens[j]).totalPartitions();

            for (uint256 k = 0; k < totalPartitions.length; k++) {
                batchTotalPartitionsResponse[counter] = totalPartitions[k];
                batchPartitionSupplies[counter] = IERC1400Extended(tokens[j]).totalSupplyByPartition(totalPartitions[k]);
                counter++;
            }
        }

        return (batchTotalPartitionsLength, batchTotalPartitionsResponse, batchPartitionSupplies);
    }

    /**
     * @dev Get batch of token default partitions.
     * @return Batch of token default partitions.
     */
    function batchDefaultPartitions(address[] memory tokens) public view returns (uint256[] memory, bytes32[] memory) {
        uint256[] memory batchDefaultPartitionsLength = new uint256[](tokens.length);
        uint256 defaultPartitionsLength=0;

        for (uint256 i = 0; i < tokens.length; i++) {
            bytes32[] memory defaultPartitions = IERC1400Extended(tokens[i]).getDefaultPartitions();
            batchDefaultPartitionsLength[i] = defaultPartitions.length;
            defaultPartitionsLength = defaultPartitionsLength.add(defaultPartitions.length);
        }

        bytes32[] memory batchDefaultPartitionsResponse = new bytes32[](defaultPartitionsLength);

        uint256 counter = 0;
        for (uint256 j = 0; j < tokens.length; j++) {
            bytes32[] memory defaultPartitions = IERC1400Extended(tokens[j]).getDefaultPartitions();

            for (uint256 k = 0; k < defaultPartitions.length; k++) {
                batchDefaultPartitionsResponse[counter] = defaultPartitions[k];
                counter++;
            }
        }

        return (batchDefaultPartitionsLength, batchDefaultPartitionsResponse);
    }

    /**
     * @dev Get batch of validation status.
     * @return Batch of validation status.
     */
    function batchValidations(address[] memory tokens, address[] memory tokenHolders) public view returns (bool[] memory, bool[] memory) {
        bool[] memory batchAllowlisted_ = batchAllowlisted(tokens, tokenHolders);
        bool[] memory batchBlocklisted_ = batchBlocklisted(tokens, tokenHolders);

        return (batchAllowlisted_, batchBlocklisted_);
    }

    /**
     * @dev Get batch of allowlisted status.
     * @return Batch of allowlisted status.
     */
    function batchAllowlisted(address[] memory tokens, address[] memory tokenHolders) public view returns (bool[] memory) {
        bool[] memory batchAllowlistedResponse = new bool[](tokenHolders.length * tokens.length);

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                address tokenExtension = interfaceAddr(tokens[j], ERC1400_TOKENS_VALIDATOR);
                if (tokenExtension != address(0)) {
                    batchAllowlistedResponse[i*tokens.length + j] = IERC1400TokensValidatorExtended(tokenExtension).isAllowlisted(tokens[j], tokenHolders[i]);
                } else {
                    batchAllowlistedResponse[i*tokens.length + j] = false;
                }
            }
        }
        return batchAllowlistedResponse;
    }

    /**
     * @dev Get batch of blocklisted status.
     * @return Batch of blocklisted status.
     */
    function batchBlocklisted(address[] memory tokens, address[] memory tokenHolders) public view returns (bool[] memory) {
        bool[] memory batchBlocklistedResponse = new bool[](tokenHolders.length * tokens.length);

        for (uint256 i = 0; i < tokenHolders.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                address tokenExtension = interfaceAddr(tokens[j], ERC1400_TOKENS_VALIDATOR);
                if (tokenExtension != address(0)) {
                    batchBlocklistedResponse[i*tokens.length + j] = IERC1400TokensValidatorExtended(tokenExtension).isBlocklisted(tokens[j], tokenHolders[i]);
                } else {
                    batchBlocklistedResponse[i*tokens.length + j] = false;
                }
            }
        }
        return batchBlocklistedResponse;
    }

}
