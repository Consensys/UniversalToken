/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "erc1820/contracts/ERC1820Client.sol";
import "../interface/ERC1820Implementer.sol";

import "../tokens/IERC20HoldableToken.sol";

interface HoldableERC1400TokenExtension {
    enum HoldStatusCode {
        Nonexistent,
        Ordered,
        Executed,
        ExecutedAndKeptOpen,
        ReleasedByNotary,
        ReleasedByPayee,
        ReleasedOnExpiration
    }

    function executeHold(
        address token,
        bytes32 holdId,
        uint256 value,
        bytes32 lockPreimage
    ) external;

    function retrieveHoldData(address token, bytes32 holdId) external view returns (
        bytes32 partition,
        address sender,
        address recipient,
        address notary,
        uint256 value,
        uint256 expiration,
        bytes32 secretHash,
        bytes32 secret,
        HoldStatusCode status
    );
}

/**
 * @title DVPHoldableLockable
 * @notice Facilitates the atomic settlement of ERC20 and ERC1400 Holdable Tokens.
 */
contract DVPHoldableLockable is ERC1820Client, ERC1820Implementer {
    string internal constant DVP_HOLDABLE_LOCKABLE = "DVPHoldableLockable";
    
    string internal constant ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

    enum Standard {Undefined, HoldableERC20, HoldableERC1400}

    event ExecuteHolds(
        address indexed token1,
        bytes32 token1HoldId,
        address indexed token2,
        bytes32 token2HoldId,
        bytes32 preimage,
        address token1Recipient,
        address token2Recipient
    );

    /**
    @dev Include token events so they can be parsed by Ethereum clients from the settlement transactions.
     */
    // Holdable
    event ExecutedHold(bytes32 indexed holdId, bytes32 lockPreimage);
    event ExecutedHold(
        bytes32 indexed holdId,
        bytes32 lockPreimage,
        address recipient
    );
    // ERC20
    event Transfer(address indexed from, address indexed to, uint256 tokens);
    // ERC1400
    event TransferByPartition(
        bytes32 indexed fromPartition,
        address operator,
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data,
        bytes operatorData
    );
    event CreateNote(
        address indexed owner,
        bytes32 indexed noteHash,
        bytes metadata
    );
    event DestroyNote(address indexed owner, bytes32 indexed noteHash);

    /**
     * [DVP CONSTRUCTOR]
     */
    constructor() public {
        ERC1820Implementer._setInterface(DVP_HOLDABLE_LOCKABLE);
    }

    /**
     @notice Execute holds where the hold recipients are already known
     @param token1 contract address of the first token
     @param token1HoldId 32 byte hold identified from the first token
     @param tokenStandard1 Standard enum indicating if the first token is HoldableERC20 or HoldableERC1400
     @param token2 contract address of the second token
     @param token2HoldId 32 byte hold identified from the second token
     @param tokenStandard2 Standard enum indicating if the second token is HoldableERC20 or HoldableERC1400
     @param preimage optional preimage of the SHA256 hash used to lock both the token holds. This can be a zero address if no lock hash was used.
     */
    function executeHolds(
        address token1,
        bytes32 token1HoldId,
        Standard tokenStandard1,
        address token2,
        bytes32 token2HoldId,
        Standard tokenStandard2,
        bytes32 preimage
    ) public {
        _executeHolds(
            token1,
            token1HoldId,
            tokenStandard1,
            token2,
            token2HoldId,
            tokenStandard2,
            preimage,
            address(0),
            address(0)
        );
    }

    /**
     @notice Execute holds where the hold recipients are only known at execution.
     @param token1 contract address of the first token
     @param token1HoldId 32 byte hold identified from the first token
     @param tokenStandard1 Standard enum indicating if the first token is HoldableERC20 or HoldableERC1400
     @param token2 contract address of the second token
     @param token2HoldId 32 byte hold identified from the second token
     @param tokenStandard2 Standard enum indicating if the second token is HoldableERC20 or HoldableERC1400
     @param preimage optional preimage of the SHA256 hash used to lock both the token holds. This can be a zero address if no lock hash was used.
     @param token1Recipient address of the recipient of the first tokens.
     @param token2Recipient address of the recipient of the second tokens.
     */
    function executeHolds(
        address token1,
        bytes32 token1HoldId,
        Standard tokenStandard1,
        address token2,
        bytes32 token2HoldId,
        Standard tokenStandard2,
        bytes32 preimage,
        address token1Recipient,
        address token2Recipient
    ) public {
        _executeHolds(
            token1,
            token1HoldId,
            tokenStandard1,
            token2,
            token2HoldId,
            tokenStandard2,
            preimage,
            token1Recipient,
            token2Recipient
        );
    }

    /**
     @dev this is in a separate function to work around stack too deep problems
     */
    function _executeHolds(
        address token1,
        bytes32 token1HoldId,
        Standard tokenStandard1,
        address token2,
        bytes32 token2HoldId,
        Standard tokenStandard2,
        bytes32 preimage,
        address token1Recipient,
        address token2Recipient
    ) internal {
        // Token 1
        if (tokenStandard1 == Standard.HoldableERC20) {
            _executeERC20Hold(token1, token1HoldId, preimage, token1Recipient);
        } else if (tokenStandard1 == Standard.HoldableERC1400) {
            _executeERC1400Hold(
                token1,
                token1HoldId,
                preimage
            );
        } else {
            revert("invalid token standard");
        }

        // Token 2
        if (tokenStandard2 == Standard.HoldableERC20) {
            _executeERC20Hold(token2, token2HoldId, preimage, token2Recipient);
        } else if (tokenStandard2 == Standard.HoldableERC1400) {
            _executeERC1400Hold(
                token2,
                token2HoldId,
                preimage
            );
        } else {
            revert("invalid token standard");
        }

        emit ExecuteHolds(
            token1,
            token1HoldId,
            token2,
            token2HoldId,
            preimage,
            token1Recipient,
            token2Recipient
        );
    }

    function _executeERC20Hold(
        address token,
        bytes32 tokenHoldId,
        bytes32 preimage,
        address tokenRecipient
    ) internal {
        require(token != address(0), "token can not be a zero address");

        if (tokenRecipient == address(0)) {
            IERC20HoldableToken(token).executeHold(tokenHoldId, preimage);
        } else {
            IERC20HoldableToken(token).executeHold(
                tokenHoldId,
                preimage,
                tokenRecipient
            );
        }
    }

    function _executeERC1400Hold(
        address token,
        bytes32 tokenHoldId,
        bytes32 preimage
    ) internal {
        require(token != address(0), "token can not be a zero address");

        address tokenExtension = interfaceAddr(token, ERC1400_TOKENS_VALIDATOR);
        require(
            tokenExtension != address(0),
            "token has no holdable token extension"
        );

        uint256 holdValue;
        (,,,,holdValue,,,,) = HoldableERC1400TokenExtension(tokenExtension).retrieveHoldData(token, tokenHoldId);

        HoldableERC1400TokenExtension(tokenExtension).executeHold(
            token,
            tokenHoldId,
            holdValue,
            preimage
        );
    }
}
