pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ERC20Extension} from "../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../../../tokens/IERC20HoldableToken.sol";

contract HoldExtension is ERC20Extension {
    using SafeMath for uint256;
    bytes32 constant HOLD_DATA_SLOT = keccak256("holdable.holddata");

    enum HoldStatusCode {Nonexistent, Held, Executed, Released}

    struct HoldData {
        address sender;
        address recipient;
        address notary;
        uint256 amount;
        uint256 expirationDateTime;
        bytes32 lockHash;
        HoldStatusCode status;
    }

    struct HoldExtensionData {
        // mapping of accounts to hold data
        mapping(bytes32 => HoldData) holds;
        // mapping of accounts and their total amount on hold
        mapping(address => uint256) accountHoldBalances;

        uint256 totalSupplyOnHold;
    }


    constructor() {

    }

    function holdData() internal pure returns (HoldExtensionData storage ds) {
        bytes32 position = HOLD_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function initalize() external override {

    }

    modifier isHeld(bytes32 holdId) {
        HoldExtensionData storage data = holdData();
        require(
            data.holds[holdId].status == HoldStatusCode.Held,
            "Hold is not in Held status"
        );
        _;
    }

    /**
     @notice Called by the sender to hold some tokens for a recipient that the sender can not release back to themself until after the expiration date.
     @param recipient optional account the tokens will be transferred to on execution. If a zero address, the recipient must be specified on execution of the hold.
     @param notary account that can execute the hold. Typically the recipient but can be a third party or a smart contact.
     @param amount of tokens to be transferred to the recipient on execution. Must be a non zero amount.
     @param expirationDateTime UNIX epoch seconds the held amount can be released back to the sender by the sender. Past dates are allowed.
     @param lockHash optional keccak256 hash of a lock preimage. An empty hash will not enforce the hash lock when the hold is executed.
     @return holdId a unique identifier for the hold.
     */
    function hold(
        address recipient,
        address notary,
        uint256 amount,
        uint256 expirationDateTime,
        bytes32 lockHash
    ) public returns (bytes32 holdId) {
        require(
            notary != address(0),
            "hold: notary must not be a zero address"
        );
        require(amount != 0, "hold: amount must be greater than zero");
        //TODO Add extension API for ERC20 view functions
        /* require(
            this.balanceOf(msg.sender) >= amount,
            "hold: amount exceeds available balance"
        ); */
        holdId = keccak256(
            abi.encodePacked(
                recipient,
                notary,
                amount,
                expirationDateTime,
                lockHash
            )
        );

        HoldExtensionData storage data = holdData();

        require(
            data.holds[holdId].status == HoldStatusCode.Nonexistent,
            "hold: id already exists"
        );
        data.holds[holdId] = HoldData(
            msg.sender,
            recipient,
            notary,
            amount,
            expirationDateTime,
            lockHash,
            HoldStatusCode.Held
        );
        data.accountHoldBalances[msg.sender] = data.accountHoldBalances[msg.sender].add(
            amount
        );
        data.totalSupplyOnHold = data.totalSupplyOnHold.add(amount);

        /* emit NewHold(
            holdId,
            recipient,
            notary,
            amount,
            expirationDateTime,
            lockHash
        ); */
    }

    /**
     @notice Called by the notary to transfer the held tokens to the set at the hold recipient if there is no hash lock.
     @param holdId a unique identifier for the hold.
     */
    function executeHold(bytes32 holdId) public {
        HoldExtensionData storage data = holdData();

        require(
            data.holds[holdId].recipient != address(0),
            "executeHold: must pass the recipient on execution as the recipient was not set on hold"
        );
        require(
            data.holds[holdId].lockHash == bytes32(0),
            "executeHold: need preimage if the hold has a lock hash"
        );

        _executeHold(holdId, "", data.holds[holdId].recipient);
    }

    /**
     @notice Called by the notary to transfer the held tokens to the recipient that was set at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a sha256 hash
     */
    function executeHold(bytes32 holdId, bytes32 lockPreimage) public {
        HoldExtensionData storage data = holdData();
        
        require(
            data.holds[holdId].recipient != address(0),
            "executeHold: must pass the recipient on execution as the recipient was not set on hold"
        );
        if (data.holds[holdId].lockHash != bytes32(0)) {
            require(
                data.holds[holdId].lockHash ==
                    sha256(abi.encodePacked(lockPreimage)),
                "executeHold: preimage hash does not match lock hash"
            );
        }

        _executeHold(holdId, lockPreimage, data.holds[holdId].recipient);
    }

    /**
     @notice Called by the notary to transfer the held tokens to the recipient if no recipient was specified at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a keccak256 hash
     @param recipient the account the tokens will be transferred to on execution.
     */
    function executeHold(
        bytes32 holdId,
        bytes32 lockPreimage,
        address recipient
    ) public {
        HoldExtensionData storage data = holdData();
        require(
            data.holds[holdId].recipient == address(0),
            "executeHold: can not set a recipient on execution as it was set on hold"
        );
        require(
            recipient != address(0),
            "executeHold: recipient must not be a zero address"
        );
        if (data.holds[holdId].lockHash != bytes32(0)) {
            require(
                data.holds[holdId].lockHash ==
                    sha256(abi.encodePacked(lockPreimage)),
                "executeHold: preimage hash does not match lock hash"
            );
        }

        data.holds[holdId].recipient = recipient;

        _executeHold(holdId, lockPreimage, recipient);
    }

    function _executeHold(
        bytes32 holdId,
        bytes32 lockPreimage,
        address recipient
    ) internal isHeld(holdId) {
        HoldExtensionData storage data = holdData();

        require(
            data.holds[holdId].notary == msg.sender,
            "executeHold: caller must be the hold notary"
        );

        super._transfer(data.holds[holdId].sender, recipient, data.holds[holdId].amount);

        data.holds[holdId].status = HoldStatusCode.Executed;
        data.accountHoldBalances[data.holds[holdId]
            .sender] = data.accountHoldBalances[data.holds[holdId].sender].sub(
            data.holds[holdId].amount
        );
        data.totalSupplyOnHold = data.totalSupplyOnHold.sub(data.holds[holdId].amount);

        //emit ExecutedHold(holdId, lockPreimage, recipient);
    }

    /**
     @notice Called by the notary at any time or the sender after the expiration date to release the held tokens back to the sender.
     @param holdId a unique identifier for the hold.
     */
    function releaseHold(bytes32 holdId) public isHeld(holdId) {
        HoldExtensionData storage data = holdData();
        
        if (data.holds[holdId].sender == msg.sender) {
            require(
                block.timestamp > data.holds[holdId].expirationDateTime,
                "releaseHold: can only release after the expiration date."
            );
        } else if (data.holds[holdId].notary != msg.sender) {
            revert("releaseHold: caller must be the hold sender or notary.");
        }

        data.holds[holdId].status = HoldStatusCode.Released;
        data.accountHoldBalances[data.holds[holdId]
            .sender] = data.accountHoldBalances[data.holds[holdId].sender].sub(
            data.holds[holdId].amount
        );
        data.totalSupplyOnHold = data.totalSupplyOnHold.sub(data.holds[holdId].amount);

        //emit ReleaseHold(holdId, msg.sender);
    }

    /**
     @notice Amount of tokens owned by an account that are held pending execution or release.
     @param account owner of the tokens
     */
    function balanceOnHold(address account) public view returns (uint256) {
        HoldExtensionData storage data = holdData();
        return data.accountHoldBalances[account];
    }

    /**
     @notice Total amount of tokens owned by an account including all the held tokens pending execution or release.
     @param account owner of the tokens
     */
    function spendableBalanceOf(address account) public view returns (uint256) {
        HoldExtensionData storage data = holdData();
        //TODO Add view functions to extensions
        return super.balanceOf(account) - data.accountHoldBalances[account];
    }

    /**
     @param holdId a unique identifier for the hold.
     @return hold status code.
     */
    function holdStatus(bytes32 holdId) public view returns (HoldStatusCode) {
        HoldExtensionData storage data = holdData();
        return data.holds[holdId].status;
    }


    function validateTransfer(TransferData memory data) external override view returns (bool) {

        return true;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {

        return true;
    }
}