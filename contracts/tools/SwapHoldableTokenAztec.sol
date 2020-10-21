/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "./SwapHoldableToken.sol";

/**
 @notice Interface to the Aztec Cryptography Engine (ACE) to validate proofs
*/
interface AztecCryptographyEngine {
    function validateProof(
        uint24 proofId,
        address zeroKnowledgeAsset,
        bytes calldata proofData
    ) external;
}

/**
 @title SwapHoldableTokenAztec
 @notice extends SwapHoldableToken so Aztec notes can be atomically settled.
*/
contract SwapHoldableTokenAztec is SwapHoldableToken {
    AztecCryptographyEngine aceContract;

    /**
     @param _aceContract contract address of the deployed Aztec Cryptography Engine (ACE). eg 0xb9Bb032206Da5B033a47E62D905F26269DAbE839 for mainnet
     */
    constructor(address _aceContract) public {
        require(
            _aceContract != address(0),
            "ACE address must not be a zero address"
        );
        aceContract = AztecCryptographyEngine(_aceContract);
    }

    /**
     @notice this must be called before holds on Aztec notes are settled so the swap contract has permission to execute the proof holding the notes.
     @param proofId the Aztec proof version identifier. eg JOIN_SPLIT_PROOF = 65793. Use the proofs constants in the aztec.js package.
     @param proofData Aztec ABI encoded proof data.
     */
    function validateProof(uint24 proofId, bytes calldata proofData) external {
        aceContract.validateProof(proofId, address(this), proofData);
    }
}
