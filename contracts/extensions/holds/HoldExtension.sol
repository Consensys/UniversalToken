pragma solidity ^0.8.0;

import "@gnus.ai/contracts-upgradeable-diamond/utils/math/SafeMathUpgradeable.sol";
import {TokenExtension, TransferData, TokenStandard} from "../TokenExtension.sol";
import {IHoldableToken, ERC20HoldData, HoldStatusCode} from "../../interface/IHoldableToken.sol";

contract HoldExtension is TokenExtension, IHoldableToken {
    using SafeMathUpgradeable for uint256;
    bytes32 constant HOLD_DATA_SLOT = keccak256("consensys.contracts.token.ext.storage.holdable.data");

    struct HoldExtensionData {
        // mapping of accounts to hold data
        mapping(bytes32 => ERC20HoldData) holds;
        // mapping of accounts and their total amount on hold
        mapping(address => uint256) accountHoldBalances;

        mapping(bytes32 => bytes32) holdHashToId;

        uint256 totalSupplyOnHold;
    }


    constructor() {
        _setPackageName("net.consensys.tokenext.HoldExtension");
        _setInterfaceLabel("HoldExtension");
        _supportsTokenStandard(TokenStandard.ERC20);
        _setVersion(1);

        _registerFunction(this.hold.selector);
        _registerFunction(this.releaseHold.selector);
        _registerFunction(this.balanceOnHold.selector);
        _registerFunction(this.spendableBalanceOf.selector);
        _registerFunction(this.holdStatus.selector);
        //Need to do by name, this.executeHold.selector is ambigious
        _registerFunctionName("executeHold(bytes32)");
        _registerFunctionName("executeHold(bytes32,bytes32)");
        _registerFunctionName("executeHold(bytes32,bytes32,address)");


    }

    function holdData() internal pure returns (HoldExtensionData storage ds) {
        bytes32 position = HOLD_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function initialize() external override {
        _listenForTokenBeforeTransfers(this.onTransferExecuted);
        _listenForTokenApprovals(this.onApproveExecuted);
    }

    modifier isHeld(bytes32 holdId) {
        HoldExtensionData storage data = holdData();
        require(
            data.holds[holdId].status == HoldStatusCode.Ordered ||
            data.holds[holdId].status == HoldStatusCode.ExecutedAndKeptOpen,
            "Hold is not in Ordered status"
        );
        _;
    }

    function generateHoldId(
        address recipient,
        address notary,
        uint256 amount,
        uint256 expirationDateTime,
        bytes32 lockHash
    ) external pure returns (bytes32 holdId) {
        holdId = keccak256(
            abi.encodePacked(
                recipient,
                notary,
                amount,
                expirationDateTime,
                lockHash
            )
        );
    }

    /**
    * @dev Retrieve hold hash, and ID for given parameters
    */
    function retrieveHoldHashId(address notary, address sender, address recipient, uint value) public view returns (bytes32, bytes32) {
        HoldExtensionData storage data = holdData();
        // Pack and hash hold parameters
        bytes32 holdHash = keccak256(abi.encodePacked(
            address(this), //Include the token address to indicate domain
            sender,
            recipient,
            notary,
            value
        ));
        bytes32 holdId = data.holdHashToId[holdHash];

        return (holdHash, holdId);
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
        bytes32 holdId,
        address recipient,
        address notary,
        uint256 amount,
        uint256 expirationDateTime,
        bytes32 lockHash
    ) public override returns (bool) {
        require(
            notary != address(0),
            "hold: notary must not be a zero address"
        );
        require(amount != 0, "hold: amount must be greater than zero");
        require(
            this.spendableBalanceOf(_msgSender()) >= amount,
            "hold: amount exceeds available balance"
        );

        HoldExtensionData storage data = holdData();

        (bytes32 holdHash,) = retrieveHoldHashId(
            notary,
            _msgSender(),
            recipient,
            amount
        );

        data.holdHashToId[holdHash] = holdId;

        require(
            data.holds[holdId].status == HoldStatusCode.Nonexistent,
            "hold: id already exists"
        );
        data.holds[holdId] = ERC20HoldData(
            _msgSender(),
            recipient,
            notary,
            amount,
            expirationDateTime,
            lockHash,
            HoldStatusCode.Ordered
        );
        data.accountHoldBalances[_msgSender()] = data.accountHoldBalances[_msgSender()].add(
            amount
        );
        data.totalSupplyOnHold = data.totalSupplyOnHold.add(amount);

        emit NewHold(
            holdId,
            recipient,
            notary,
            amount,
            expirationDateTime,
            lockHash
        );

        return true;
    }

    function retrieveHoldData(bytes32 holdId) external override view returns (ERC20HoldData memory) {
        HoldExtensionData storage data = holdData();
        return data.holds[holdId];
    }

        /**
     @notice Called by the notary to transfer the held tokens to the set at the hold recipient if there is no hash lock.
     @param holdId a unique identifier for the hold.
     */
    function executeHold(bytes32 holdId) public override {
        HoldExtensionData storage data = holdData();

        require(
            data.holds[holdId].recipient != address(0),
            "executeHold: must pass the recipient on execution as the recipient was not set on hold"
        );
        require(
            data.holds[holdId].secretHash == bytes32(0),
            "executeHold: need preimage if the hold has a lock hash"
        );

        _executeHold(holdId, "", data.holds[holdId].recipient);
    }

    /**
     @notice Called by the notary to transfer the held tokens to the recipient that was set at the hold.
     @param holdId a unique identifier for the hold.
     @param lockPreimage the image used to generate the lock hash with a sha256 hash
     */
    function executeHold(bytes32 holdId, bytes32 lockPreimage) public override {
        HoldExtensionData storage data = holdData();

        require(
            data.holds[holdId].recipient != address(0),
            "executeHold: must pass the recipient on execution as the recipient was not set on hold"
        );
        if (data.holds[holdId].secretHash != bytes32(0)) {
            require(
                data.holds[holdId].secretHash ==
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
    ) public override {
        HoldExtensionData storage data = holdData();
        require(
            data.holds[holdId].recipient == address(0),
            "executeHold: can not set a recipient on execution as it was set on hold"
        );
        require(
            recipient != address(0),
            "executeHold: recipient must not be a zero address"
        );
        if (data.holds[holdId].secretHash != bytes32(0)) {
            require(
                data.holds[holdId].secretHash ==
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

        data.holds[holdId].status = HoldStatusCode.Executing;

        TransferData memory transferData = _buildTransferWithOperatorData(data.holds[holdId].sender, recipient, data.holds[holdId].amount, abi.encode(holdId));
        _tokenTransfer(transferData);
        //super._transfer(holds[holdId].sender, recipient, holds[holdId].amount);

        data.holds[holdId].status = HoldStatusCode.Executed;
        data.accountHoldBalances[data.holds[holdId]
            .sender] = data.accountHoldBalances[data.holds[holdId].sender].sub(
            data.holds[holdId].amount
        );
        data.totalSupplyOnHold = data.totalSupplyOnHold.sub(data.holds[holdId].amount);

        (bytes32 holdHash,) = retrieveHoldHashId(
            data.holds[holdId].notary,
            data.holds[holdId].sender,
            data.holds[holdId].recipient,
            data.holds[holdId].amount
        );

        delete data.holdHashToId[holdHash];

        emit ExecutedHold(holdId, lockPreimage, recipient);
    }

    /**
     @notice Called by the notary at any time or the sender after the expiration date to release the held tokens back to the sender.
     @param holdId a unique identifier for the hold.
     */
    function releaseHold(bytes32 holdId) public override isHeld(holdId) {
        HoldExtensionData storage data = holdData();

        if (data.holds[holdId].sender == _msgSender()) {
            require(
                block.timestamp > data.holds[holdId].expirationDateTime,
                "releaseHold: can only release after the expiration date."
            );
            data.holds[holdId].status = HoldStatusCode.ReleasedOnExpiration;
        } else if (data.holds[holdId].notary != _msgSender()) {
            revert("releaseHold: caller must be the hold sender or notary.");
        } else {
            data.holds[holdId].status = HoldStatusCode.ReleasedByNotary;
        }

        data.accountHoldBalances[data.holds[holdId]
            .sender] = data.accountHoldBalances[data.holds[holdId].sender].sub(
            data.holds[holdId].amount
        );
        data.totalSupplyOnHold = data.totalSupplyOnHold.sub(data.holds[holdId].amount);

        emit ReleaseHold(holdId, _msgSender());
    }

    /**
     @notice Amount of tokens owned by an account that are held pending execution or release.
     @param account owner of the tokens
     */
    function balanceOnHold(address account) public override view returns (uint256) {
        HoldExtensionData storage data = holdData();
        return data.accountHoldBalances[account];
    }

    /**
     @notice Total amount of tokens owned by an account including all the held tokens pending execution or release.
     @param account owner of the tokens
     */
    function spendableBalanceOf(address account) public override view returns (uint256) {
        HoldExtensionData storage data = holdData();
        //if (_tokenStandard() == TokenStandard.ERC20) {
        return _erc20Token().balanceOf(account) - data.accountHoldBalances[account];
        //} else {
            //TODO Add support for other tokens
        //    revert("Stnadard not supported");
        //}
    }

    function totalSupplyOnHold() external override view returns (uint256) {
        HoldExtensionData storage data = holdData();
        return data.totalSupplyOnHold;
    }

    /**
     @param holdId a unique identifier for the hold.
     @return hold status code.
     */
    function holdStatus(bytes32 holdId) public override view returns (HoldStatusCode) {
        HoldExtensionData storage data = holdData();
        return data.holds[holdId].status;
    }

    function onTransferExecuted(TransferData memory data) external virtual eventGuard returns (bool) {
        //only check if not a mint
        if (data.from != address(0)) {
            if (data.operatorData.length > 0 && data.operator == _extensionAddress()) {
                //Dont trigger normal spendableBalanceOf check
                //if we triggered this transfer as a result of _executeHold
                (bytes32 holdId) = abi.decode(data.operatorData, (bytes32));
                HoldExtensionData storage hd = holdData();
                require(hd.holds[holdId].status == HoldStatusCode.Executing, "Hold in weird state");
            } else {
                require(spendableBalanceOf(data.from) >= data.value, "HoldableToken: amount exceeds available balance (transfer)");
            }
        }
        return true;
    }

    function onApproveExecuted(TransferData memory data) external virtual eventGuard returns (bool) {
        require(spendableBalanceOf(data.from) >= data.value, "HoldableToken: amount exceeds available balance (approve)");
        return true;
    }
}