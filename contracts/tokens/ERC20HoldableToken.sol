/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "./ERC20Token.sol";
import "./IERC20HoldableToken.sol";

/**
 * @title ERC20HoldableToken
 * @notice A hold is like an approve where held tokens can not be spent by the token holder until after an hold expiration period.
    The hold can be executed by a notary, which can be the recipient of the tokens, a third party or a smart contract.
    The notary can execute the hold before or after the expiration period.
    Additionally, a hash lock at be applied which requires the notary of the hold to present the hash preimage to execute the hold.
    Held tokens can be released by the notary at any time or by the token holder after the expiration period.
    A recipient does not have to get set at the time of the hold, which means it will have to be specified when the hold is executed.
 */
contract ERC20HoldableToken is IERC20HoldableToken, ERC20Token {
    struct HoldData {
        address sender;
        address recipient;
        address notary;
        uint256 amount;
        uint256 expirationDateTime;
        bytes32 lockHash;
        HoldStatusCode status;
    }

    // mapping of accounts to hold data
    mapping(bytes32 => HoldData) internal holds;
    // mapping of accounts and their total amount on hold
    mapping(address => uint256) internal accountHoldBalances;
    uint256 public totalSupplyOnHold;

    modifier isHeld(bytes32 holdId) {
        require(
            holds[holdId].status == HoldStatusCode.Held,
            "Hold is not in Held status"
        );
        _;
    }

    constructor(string memory name, string memory symbol, uint8 decimals) public ERC20Token(name, symbol, decimals) {}

    /**
     @notice Called by the sender to hold some tokens for a recipient that the sender can not release back to themself until after the expiration date.
     @param recipient optional account the tokens will be transferred to on execution. If a zero address, the recipient must be specified on execution of the hold.
     @param notary account that can execute the hold. Typically the recipient but can be a third party or a smart contact.
     @param amount of tokens to be transferred to the recipient on execution. Must be a non zero amount.
     @param expirationDateTime UNIX epoch seconds the held amount can be released back to the sender by the sender. Past dates are allowed.
     @param lockHash optional keccak256 hash of a lock preimage. An empty hash will not enforce the hash lock when the hold is executed.
     @return a unique identifier for the hold.
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
        require(
            this.balanceOf(msg.sender) >= amount,
            "hold: amount exceeds available balance"
        );
        holdId = keccak256(
            abi.encodePacked(
                recipient,
                notary,
                amount,
                expirationDateTime,
                lockHash
            )
        );
        require(
            holds[holdId].status == HoldStatusCode.Nonexistent,
            "hold: id already exists"
        );
        holds[holdId] = HoldData(
            msg.sender,
            recipient,
            notary,
            amount,
            expirationDateTime,
            lockHash,
            HoldStatusCode.Held
        );
        accountHoldBalances[msg.sender] = accountHoldBalances[msg.sender].add(
            amount
        );
        totalSupplyOnHold = totalSupplyOnHold.add(amount);

        emit NewHold(
            holdId,
            recipient,
            notary,
            amount,
            expirationDateTime,
            lockHash
        );
    }

    /**
     @notice Called by the notary to transfer the held tokens to the set at the hold recipient if there is no hash lock.
     @param holdId a unique identifier for the hold.
     */
    function executeHold(bytes32 holdId) public {
        require(
            holds[holdId].recipient != address(0),
            "executeHold: must pass the recipient on execution as the recipient was not set on hold"
        );
        require(
            holds[holdId].lockHash == bytes32(0),
            "executeHold: need preimage if the hold has a lock hash"
        );

        _executeHold(holdId, "", holds[holdId].recipient);
    }

    /**
     @notice Called by the notary to transfer the held tokens to the recipient that was set at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a sha256 hash
     */
    function executeHold(bytes32 holdId, bytes32 lockPreimage) public {
        require(
            holds[holdId].recipient != address(0),
            "executeHold: must pass the recipient on execution as the recipient was not set on hold"
        );
        if (holds[holdId].lockHash != bytes32(0)) {
            require(
                holds[holdId].lockHash ==
                    sha256(abi.encodePacked(lockPreimage)),
                "executeHold: preimage hash does not match lock hash"
            );
        }

        _executeHold(holdId, lockPreimage, holds[holdId].recipient);
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
        require(
            holds[holdId].recipient == address(0),
            "executeHold: can not set a recipient on execution as it was set on hold"
        );
        require(
            recipient != address(0),
            "executeHold: recipient must not be a zero address"
        );
        if (holds[holdId].lockHash != bytes32(0)) {
            require(
                holds[holdId].lockHash ==
                    sha256(abi.encodePacked(lockPreimage)),
                "executeHold: preimage hash does not match lock hash"
            );
        }

        holds[holdId].recipient = recipient;

        _executeHold(holdId, lockPreimage, recipient);
    }

    function _executeHold(
        bytes32 holdId,
        bytes32 lockPreimage,
        address recipient
    ) internal isHeld(holdId) {
        require(
            holds[holdId].notary == msg.sender,
            "executeHold: caller must be the hold notary"
        );

        super._transfer(holds[holdId].sender, recipient, holds[holdId].amount);

        holds[holdId].status = HoldStatusCode.Executed;
        accountHoldBalances[holds[holdId]
            .sender] = accountHoldBalances[holds[holdId].sender].sub(
            holds[holdId].amount
        );
        totalSupplyOnHold = totalSupplyOnHold.sub(holds[holdId].amount);

        emit ExecutedHold(holdId, lockPreimage, recipient);
    }

    /**
     @notice Called by the notary at any time or the sender after the expiration date to release the held tokens back to the sender.
     @param holdId a unique identifier for the hold.
     */
    function releaseHold(bytes32 holdId) public isHeld(holdId) {
        if (holds[holdId].sender == msg.sender) {
            require(
                now > holds[holdId].expirationDateTime,
                "releaseHold: can only release after the expiration date."
            );
        } else if (holds[holdId].notary != msg.sender) {
            revert("releaseHold: caller must be the hold sender or notary.");
        }

        holds[holdId].status = HoldStatusCode.Released;
        accountHoldBalances[holds[holdId]
            .sender] = accountHoldBalances[holds[holdId].sender].sub(
            holds[holdId].amount
        );
        totalSupplyOnHold = totalSupplyOnHold.sub(holds[holdId].amount);

        emit ReleaseHold(holdId, msg.sender);
    }

    /**
     @notice Amount of tokens owned by an account that are available for transfer. That is, the gross balance less any held tokens.
     @param account owner of the tokensß
     */
    function balanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account).sub(accountHoldBalances[account]);
    }

    /**
     @notice Amount of tokens owned by an account that are held pending execution or release.
     @param account owner of the tokens
     */
    function holdBalanceOf(address account) public view returns (uint256) {
        return accountHoldBalances[account];
    }

    /**
     @notice Total amount of tokens owned by an account including all the held tokens pending execution or release.
     @param account owner of the tokens
     */
    function grossBalanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    /**
     @param holdId a unique identifier for the hold.
     @return hold status code.
     */
    function holdStatus(bytes32 holdId) public view returns (HoldStatusCode) {
        return holds[holdId].status;
    }

    /**
     @notice ERC20 transfer that checks on hold tokens can not be transferred.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(
            this.balanceOf(msg.sender) >= amount,
            "HoldableToken: amount exceeds available balance"
        );
        return super.transfer(recipient, amount);
    }

    /**
     @notice ERC20 transferFrom that checks on hold tokens can not be transferred.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        require(
            this.balanceOf(sender) >= amount,
            "HoldableToken: amount exceeds available balance"
        );
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     @notice ERC20 approve that checks on hold tokens can not be approved for spending by another account.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        require(
            this.balanceOf(msg.sender) >= amount,
            "HoldableToken: amount exceeds available balance"
        );
        return super.approve(spender, amount);
    }

    /**
     @notice ERC20 burn that checks on hold tokens can not be burnt.
     */
    function burn(uint256 amount) public {
        require(
            this.balanceOf(msg.sender) >= amount,
            "HoldableToken: amount exceeds available balance"
        );
        super.burn(amount);
    }

    /**
     @notice ERC20 burnFrom that checks on hold tokens can not be burnt.
     */
    function burnFrom(address account, uint256 amount) public {
        require(
            this.balanceOf(msg.sender) >= amount,
            "HoldableToken: amount exceeds available balance"
        );
        super.burnFrom(account, amount);
    }
}
