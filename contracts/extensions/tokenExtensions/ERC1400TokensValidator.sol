/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./roles/BlacklistedRole.sol";

import "erc1820/contracts/ERC1820Client.sol";
import "../../interface/ERC1820Implementer.sol";

import "../../IERC1400.sol";

// import "../userExtensions/IERC1400TokensSender.sol";
// import "../userExtensions/IERC1400TokensRecipient.sol";

import "./IERC1400TokensValidator.sol";


contract ERC1400TokensValidator is IERC1400TokensValidator, Ownable, Pausable, WhitelistedRole, BlacklistedRole, ERC1820Client, ERC1820Implementer {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  bytes4 constant internal ERC20_TRANSFER_FUNCTION_ID = bytes4(keccak256("transfer(address,uint256)"));
  bytes4 constant internal ERC20_TRANSFERFROM_FUNCTION_ID = bytes4(keccak256("transferFrom(address,address,uint256)"));

  bool internal _whitelistActivated;
  bool internal _blacklistActivated;
  bool internal _holdsActivated;

  enum HoldStatusCode {
    Nonexistent,
    Ordered,
    Executed,
    ExecutedAndKeptOpen,
    ReleasedByNotary,
    ReleasedByPayee,
    ReleasedOnExpiration
  }

  struct Hold {
    bytes32 partition;
    address sender;
    address recipient;
    address notary;
    uint256 value;
    uint256 expiration;
    bytes32 secretHash;
    bytes32 secret;
    address paymentToken;
    uint256 paymentAmount;
    HoldStatusCode status;
  }

  // Mapping from (token, holdId) to hold.
  mapping(address => mapping(bytes32 => Hold)) internal _holds;

  // Mapping from (token, tokenHolder) to balance on hold.
  mapping(address => mapping(address => uint256)) internal _heldBalance;

  // Mapping from (token, tokenHolder, partition) to balance on hold of corresponding partition.
  mapping(address => mapping(address => mapping(bytes32 => uint256))) internal _heldBalanceByPartition;

  // Mapping from (token, partition) to global balance on hold of corresponding partition.
  mapping(address => mapping(bytes32 => uint256)) internal _totalHeldBalanceByPartition;

  // Total balance on hold.
  mapping(address => uint256) internal _totalHeldBalance;

  event HoldCreated(
    address indexed token,
    bytes32 indexed holdId,
    bytes32 partition,
    address sender,
    address recipient,
    address indexed notary,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    address paymentToken,
    uint256 paymentAmount
  );
  event HoldReleased(address indexed token, bytes32 holdId, address indexed notary, HoldStatusCode status);
  event HoldRenewed(address indexed token, bytes32 holdId, address indexed notary, uint256 oldExpiration, uint256 newExpiration);
  event HoldExecuted(address indexed token, bytes32 holdId, address indexed notary, uint256 heldValue, uint256 transferredValue, bytes32 secret);
  event HoldExecutedAndKeptOpen(address indexed token, bytes32 holdId, address indexed notary, uint256 heldValue, uint256 transferredValue, bytes32 secret);
  
  constructor(bool whitelistActivated, bool blacklistActivated, bool holdsActivated) public {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_VALIDATOR);

    _whitelistActivated = whitelistActivated;
    _blacklistActivated = blacklistActivated;
    _holdsActivated = holdsActivated;
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @param token Address of the token.
   * @param functionSig ID of the function that is called.
   * @param partition Name of the partition (left empty for ERC20 transfer).
   * @param operator Address which triggered the balance decrease (through transfer or redemption).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a redemption.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information.
   * @param operatorData Extra information, attached by the operator (if any).
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function canValidate(
    address token,
    bytes4 functionSig,
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata operatorData
  ) // Comments to avoid compilation warnings for unused variables.
    external
    view 
    returns(bool)
  {
    return(_canValidate(token, functionSig, partition, operator, from, to, value, data, operatorData));
  }

  /**
   * @dev Function called by the token contract before executing a transfer.
   * @param functionSig ID of the function that is called.
   * @param partition Name of the partition (left empty for ERC20 transfer).
   * @param operator Address which triggered the balance decrease (through transfer or redemption).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a redemption.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information.
   * @param operatorData Extra information, attached by the operator (if any).
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function tokensToValidate(
    bytes4 functionSig,
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata operatorData
  ) // Comments to avoid compilation warnings for unused variables.
    external
  {
    require(_canValidate(msg.sender, functionSig, partition, operator, from, to, value, data, operatorData), "55"); // 0x55	funds locked (lockup period)
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function _canValidate(
    address token,
    bytes4 functionSig,
    bytes32 partition,
    address /*operator*/,
    address from,
    address to,
    uint value,
    bytes memory /*data*/,
    bytes memory /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    view
    whenNotPaused
    returns(bool)
  {
    if(_functionRequiresValidation(functionSig)) {
      if(_whitelistActivated) {
        if(!isWhitelisted(from) || !isWhitelisted(to)) {
          return false;
        }
      }
      if(_blacklistActivated) {
        if(isBlacklisted(from) || isBlacklisted(to)) {
          return false;
        }
      }
    }

    if (_holdsActivated) {
      if(value > _spendableBalanceOfByPartition(token, partition, from)) {
        return false;
      }
    }
    
    return true;
  }

  /**
   * @dev Check if validator is activated for the function called in the smart contract.
   * @param functionSig ID of the function that is called.
   * @return 'true' if the function requires validation, 'false' if not.
   */
  function _functionRequiresValidation(bytes4 functionSig) internal pure returns(bool) {

    if(areEqual(functionSig, ERC20_TRANSFER_FUNCTION_ID) || areEqual(functionSig, ERC20_TRANSFERFROM_FUNCTION_ID)) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Check if 2 variables of type bytes4 are identical.
   * @return 'true' if 2 variables are identical, 'false' if not.
   */
  function areEqual(bytes4 a, bytes4 b) internal pure returns(bool) {
    for (uint256 i = 0; i < a.length; i++) {
      if(a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /**
   * @dev Know if whitelist feature is activated.
   * @return bool 'true' if whitelist feature is activated, 'false' if not.
   */
  function isWhitelistActivated() external view returns (bool) {
    return _whitelistActivated;
  }

  /**
   * @dev Set whitelist activation status.
   * @param whitelistActivated 'true' if whitelist shall be activated, 'false' if not.
   */
  function setWhitelistActivated(bool whitelistActivated) external onlyOwner {
    _whitelistActivated = whitelistActivated;
  }

  /**
   * @dev Know if blacklist feature is activated.
   * @return bool 'true' if blakclist feature is activated, 'false' if not.
   */
  function isBlacklistActivated() external view returns (bool) {
    return _blacklistActivated;
  }

  /**
   * @dev Set blacklist activation status.
   * @param blacklistActivated 'true' if blacklist shall be activated, 'false' if not.
   */
  function setBlacklistActivated(bool blacklistActivated) external onlyOwner {
    _blacklistActivated = blacklistActivated;
  }

  /**
   * @dev Know if holds feature is activated.
   * @return bool 'true' if holds feature is activated, 'false' if not.
   */
  function isHoldsActivated() external view returns (bool) {
    return _holdsActivated;
  }

  /**
   * @dev Set holds activation status.
   * @param holdsActivated 'true' if holds shall be activated, 'false' if not.
   */
  function setHoldsActivated(bool holdsActivated) external onlyOwner {
    _holdsActivated = holdsActivated;
  }

  /**
   * @dev Create a new token hold.
   */
  function hold(
    address token,
    bytes32 holdId,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 timeToExpiration,
    bytes32 secretHash,
    address paymentToken,
    uint256 paymentAmount
  ) external returns (bool)
  {
    return _hold(
      token,
      holdId,
      msg.sender,
      recipient,
      notary,
      partition,
      value,
      _computeExpiration(timeToExpiration),
      secretHash,
      paymentToken,
      paymentAmount
    );
  }

  /**
   * @dev Create a new token hold on behalf of the token holder.
   */
  function holdFrom(
    address token,
    bytes32 holdId,
    address sender,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 timeToExpiration,
    bytes32 secretHash,
    address paymentToken,
    uint256 paymentAmount
  ) external returns (bool)
  {
    _checkHoldFrom(token, partition, msg.sender, sender);

    return _hold(
      token,
      holdId,
      sender,
      recipient,
      notary,
      partition,
      value,
      _computeExpiration(timeToExpiration),
      secretHash,
      paymentToken,
      paymentAmount
    );
  }

  /**
   * @dev Create a new token hold with expiration date.
   */
  function holdWithExpirationDate(
    address token,
    bytes32 holdId,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    address paymentToken,
    uint256 paymentAmount
  ) external returns (bool)
  {
    _checkExpiration(expiration);

    return _hold(
      token,
      holdId,
      msg.sender,
      recipient,
      notary,
      partition,
      value,
      expiration,
      secretHash,
      paymentToken,
      paymentAmount
    );
  }

  /**
   * @dev Create a new token hold with expiration date.
   */
  function holdFromWithExpirationDate(
    address token,
    bytes32 holdId,
    address sender,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    address paymentToken,
    uint256 paymentAmount
  ) external returns (bool)
  {
    _checkHoldFrom(token, partition, msg.sender, sender);
    _checkExpiration(expiration);

    return _hold(
      token,
      holdId,
      sender,
      recipient,
      notary,
      partition,
      value,
      expiration,
      secretHash,
      paymentToken,
      paymentAmount
    );
  }

  /**
   * @dev Create a new token hold.
   */
  function _hold(
    address token,
    bytes32 holdId,
    address sender,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    address paymentToken,
    uint256 paymentAmount
  ) internal returns (bool)
  {
    Hold storage newHold = _holds[token][holdId];

    require(recipient != address(0), "Payee address must not be zero address");
    require(value != 0, "Value must be greater than zero");
    require(newHold.value == 0, "This holdId already exists");
    require(notary != address(0), "Notary address must not be zero address");
    require(value <= _spendableBalanceOfByPartition(token, partition, sender), "Amount of the hold can't be greater than the spendable balance of the sender");

    newHold.partition = partition;
    newHold.sender = sender;
    newHold.recipient = recipient;
    newHold.notary = notary;
    newHold.value = value;
    newHold.expiration = expiration;
    newHold.secretHash = secretHash;
    newHold.paymentToken = paymentToken;
    newHold.paymentAmount = paymentAmount;
    newHold.status = HoldStatusCode.Ordered;

    _increaseHeldBalance(token, partition, sender, value);

    emit HoldCreated(
      token,
      holdId,
      partition,
      sender,
      recipient,
      notary,
      value,
      expiration,
      secretHash,
      paymentToken,
      paymentAmount
    );

    return true;
  }

  /**
   * @dev Release token hold.
   */
  function releaseHold(address token, bytes32 holdId) external returns (bool) {
    return _releaseHold(token, holdId);
  }

  /**
   * @dev Release token hold.
   */
  function _releaseHold(address token, bytes32 holdId) internal returns (bool) {
    Hold storage releasableHold = _holds[token][holdId];

    require(
        releasableHold.status == HoldStatusCode.Ordered || releasableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
        "A hold can only be released in status Ordered or ExecutedAndKeptOpen"
    );
    require(
        _isExpired(releasableHold.expiration) ||
        (msg.sender == releasableHold.notary) ||
        (msg.sender == releasableHold.recipient),
        "A not expired hold can only be released by the notary or the payee"
    );

    if (_isExpired(releasableHold.expiration)) {
        releasableHold.status = HoldStatusCode.ReleasedOnExpiration;
    } else {
        if (releasableHold.notary == msg.sender) {
            releasableHold.status = HoldStatusCode.ReleasedByNotary;
        } else {
            releasableHold.status = HoldStatusCode.ReleasedByPayee;
        }
    }

    _decreaseHeldBalance(token, releasableHold.partition, releasableHold.sender, releasableHold.value);

    emit HoldReleased(token, holdId, releasableHold.notary, releasableHold.status);

    return true;
  }

  /**
   * @dev Renew hold.
   */
  function renewHold(address token, bytes32 holdId, uint256 timeToExpiration) external returns (bool) {
    return _renewHold(token, holdId, _computeExpiration(timeToExpiration));
  }

  /**
   * @dev Renew hold with expiration time.
   */
  function renewHoldWithExpirationDate(address token, bytes32 holdId, uint256 expiration) external returns (bool) {
    _checkExpiration(expiration);

    return _renewHold(token, holdId, expiration);
  }

  /**
   * @dev Renew hold.
   */
  function _renewHold(address token, bytes32 holdId, uint256 expiration) internal returns (bool) {
    Hold storage renewableHold = _holds[token][holdId];

    require(
      renewableHold.status == HoldStatusCode.Ordered
      || renewableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
      "A hold can only be renewed in status Ordered or ExecutedAndKeptOpen"
    );
    require(!_isExpired(renewableHold.expiration), "An expired hold can not be renewed");
    require(
      renewableHold.sender == msg.sender
      || IERC1400(token).isOperatorForPartition(renewableHold.partition, msg.sender, renewableHold.sender),
      "The hold can only be renewed by the issuer or the payer"
    );
    
    uint256 oldExpiration = renewableHold.expiration;
    renewableHold.expiration = expiration;

    emit HoldRenewed(
      token,
      holdId,
      renewableHold.notary,
      oldExpiration,
      expiration
    );

    return true;
  }

  /**
   * @dev Execute hold.
   */
  function executeHold(address token, bytes32 holdId, uint256 value, bytes32 secret) external returns (bool) {
    return _executeHold(
      token,
      holdId,
      value,
      secret,
      false
    );
  }

  /**
   * @dev Execute hold and keep open.
   */
  function executeHoldAndKeepOpen(address token, bytes32 holdId, uint256 value, bytes32 secret) external returns (bool) {
    return _executeHold(
      token,
      holdId,
      value,
      secret,
      true
    );
  }

  /**
   * @dev Execute hold.
   */
  function _executeHold(
    address token,
    bytes32 holdId,
    uint256 value,
    bytes32 secret,
    bool keepOpenIfHoldHasBalance
  ) internal returns (bool)
  {
    Hold storage executableHold = _holds[token][holdId];

    require(
      executableHold.status == HoldStatusCode.Ordered || executableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
      "A hold can only be executed in status Ordered or ExecutedAndKeptOpen"
    );
    require(value != 0, "Value must be greater than zero");
    require(
      (executableHold.recipient == msg.sender && _checkSecret(executableHold, secret))
      || executableHold.notary == msg.sender,
      "The hold can only be executed by the recipient with the secret or by the notary");
    require(!_isExpired(executableHold.expiration), "The hold has already expired");
    require(value <= executableHold.value, "The value should be equal or less than the held amount");

    if (keepOpenIfHoldHasBalance && ((executableHold.value - value) > 0)) {
      _setHoldToExecutedAndKeptOpen(
        token,
        executableHold,
        holdId,
        value,
        value,
        secret
      );
    } else {
      _setHoldToExecuted(
        token,
        executableHold,
        holdId,
        value,
        executableHold.value,
        secret
      );
    }

    IERC1400(token).operatorTransferByPartition(executableHold.partition, executableHold.sender, executableHold.recipient, value, "", "");

    return true;
  }

  /**
   * @dev Set hold to executed.
   */
  function _setHoldToExecuted(
    address token,
    Hold storage executableHold,
    bytes32 holdId,
    uint256 value,
    uint256 heldBalanceDecrease,
    bytes32 secret
  ) internal
  {
    _decreaseHeldBalance(token, executableHold.partition, executableHold.sender, heldBalanceDecrease);

    executableHold.status = HoldStatusCode.Executed;

    emit HoldExecuted(
      token,
      holdId,
      executableHold.notary,
      executableHold.value,
      value,
      secret
    );
  }

  /**
   * @dev Set hold to executed and kept open.
   */
  function _setHoldToExecutedAndKeptOpen(
    address token,
    Hold storage executableHold,
    bytes32 holdId,
    uint256 value,
    uint256 heldBalanceDecrease,
    bytes32 secret
  ) internal
  {
    _decreaseHeldBalance(token, executableHold.partition, executableHold.sender, heldBalanceDecrease);

    executableHold.status = HoldStatusCode.ExecutedAndKeptOpen;
    executableHold.value = executableHold.value.sub(value);

    emit HoldExecutedAndKeptOpen(
      token,
      holdId,
      executableHold.notary,
      executableHold.value,
      value,
      secret
    );
  }

  /**
   * @dev Increase held balance.
   */
  function _increaseHeldBalance(address token, bytes32 partition, address sender, uint256 value) private {
    _heldBalance[token][sender] = _heldBalance[token][sender].add(value);
    _totalHeldBalance[token] = _totalHeldBalance[token].add(value);

    _heldBalanceByPartition[token][sender][partition] = _heldBalanceByPartition[token][sender][partition].add(value);
    _totalHeldBalanceByPartition[token][partition] = _totalHeldBalanceByPartition[token][partition].add(value);
  }

  /**
   * @dev Decrease held balance.
   */
  function _decreaseHeldBalance(address token, bytes32 partition, address sender, uint256 value) private {
    _heldBalance[token][sender] = _heldBalance[token][sender].sub(value);
    _totalHeldBalance[token] = _totalHeldBalance[token].sub(value);

    _heldBalanceByPartition[token][sender][partition] = _heldBalanceByPartition[token][sender][partition].sub(value);
    _totalHeldBalanceByPartition[token][partition] = _totalHeldBalanceByPartition[token][partition].sub(value);
  }

  /**
   * @dev Check secret.
   */
  function _checkSecret(Hold storage executableHold, bytes32 secret) internal returns (bool) {
    if(executableHold.secretHash == sha256(abi.encodePacked(secret))) {
      executableHold.secret = secret;
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Compute expiration time.
   */
  function _computeExpiration(uint256 timeToExpiration) internal view returns (uint256) {
    uint256 expiration = 0;

    if (timeToExpiration != 0) {
        expiration = now.add(timeToExpiration);
    }

    return expiration;
  }

  /**
   * @dev Check expiration time.
   */
  function _checkExpiration(uint256 expiration) private view {
    require(expiration > now || expiration == 0, "Expiration date must be greater than block timestamp or zero");
  }

  /**
   * @dev Check is expiration date is past.
   */
  function _isExpired(uint256 expiration) internal view returns (bool) {
    return expiration != 0 && (now >= expiration);
  }

  /**
   * @dev Check if operator can create hold on behalf of token holder.
   */
  function _checkHoldFrom(address token, bytes32 partition, address operator, address sender) private view {
    require(sender != address(0), "Payer address must not be zero address");
    require(IERC1400(token).isOperatorForPartition(partition, operator, sender), "This operator is not authorized");
  }

  /**
   * @dev Retrieve hold data.
   */
  function retrieveHoldData(address token, bytes32 holdId) external view returns (
    bytes32 partition,
    address sender,
    address recipient,
    address notary,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    bytes32 secret,
    address paymentToken,
    uint256 paymentAmount,
    HoldStatusCode status)
  {
    Hold storage retrievedHold = _holds[token][holdId];
    return (
      retrievedHold.partition,
      retrievedHold.sender,
      retrievedHold.recipient,
      retrievedHold.notary,
      retrievedHold.value,
      retrievedHold.expiration,
      retrievedHold.secretHash,
      retrievedHold.secret,
      retrievedHold.paymentToken,
      retrievedHold.paymentAmount,
      retrievedHold.status
    );
  }

  /**
   * @dev Total supply on hold.
   */
  function totalSupplyOnHold(address token) external view returns (uint256) {
    return _totalHeldBalance[token];
  }

  /**
   * @dev Total supply on hold for a specific partition.
   */
  function totalSupplyOnHoldByPartition(address token, bytes32 partition) external view returns (uint256) {
    return _totalHeldBalanceByPartition[token][partition];
  }

  /**
   * @dev Get balance on hold of a tokenholder.
   */
  function balanceOnHold(address token, address account) external view returns (uint256) {
    return _heldBalance[token][account];
  }

  /**
   * @dev Get balance on hold of a tokenholder for a specific partition.
   */
  function balanceOnHoldByPartition(address token, bytes32 partition, address account) external view returns (uint256) {
    return _heldBalanceByPartition[token][account][partition];
  }

  /**
   * @dev Get spendable balance of a tokenholder.
   */
  function spendableBalanceOf(address token, address account) external view returns (uint256) {
    return _spendableBalanceOf(token, account);
  }

  /**
   * @dev Get spendable balance of a tokenholder for a specific partition.
   */
  function spendableBalanceOfByPartition(address token, bytes32 partition, address account) external view returns (uint256) {
    return _spendableBalanceOfByPartition(token, partition, account);
  }

  /**
   * @dev Get spendable balance of a tokenholder.
   */
  function _spendableBalanceOf(address token, address account) internal view returns (uint256) {
    return IERC20(token).balanceOf(account) - _heldBalance[token][account];
  }

  /**
   * @dev Get spendable balance of a tokenholder for a specific partition.
   */
  function _spendableBalanceOfByPartition(address token, bytes32 partition, address account) internal view returns (uint256) {
    return IERC1400(token).balanceOfByPartition(partition, account) - _heldBalanceByPartition[token][account][partition];
  }

}