// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../tools/Pausable.sol";
import "../../roles/CertificateSignerRole.sol";
import "../../roles/AllowlistedRole.sol";
import "../../roles/BlocklistedRole.sol";

import "../../interface/IHoldableERC1400TokenExtension.sol";
import "../../tools/ERC1820Client.sol";
import "../../tools/DomainAware.sol";
import "../../interface/ERC1820Implementer.sol";

import "../../IERC1400.sol";

import "./IERC1400TokensValidator.sol";

/**
 * @notice Interface to the Minterrole contract
 */
interface IMinterRole {
  function isMinter(address account) external view returns (bool);
}


contract ERC1400TokensValidator is IERC1400TokensValidator, Pausable, CertificateSignerRole, AllowlistedRole, BlocklistedRole, ERC1820Client, ERC1820Implementer, IHoldableERC1400TokenExtension {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  bytes4 constant internal ERC20_TRANSFER_ID = bytes4(keccak256("transfer(address,uint256)"));
  bytes4 constant internal ERC20_TRANSFERFROM_ID = bytes4(keccak256("transferFrom(address,address,uint256)"));

  bytes32 constant internal ZERO_ID = 0x00000000000000000000000000000000;

  // Mapping from token to token controllers.
  mapping(address => address[]) internal _tokenControllers;

  // Mapping from (token, operator) to token controller status.
  mapping(address => mapping(address => bool)) internal _isTokenController;

  // Mapping from token to allowlist activation status.
  mapping(address => bool) internal _allowlistActivated;

  // Mapping from token to blocklist activation status.
  mapping(address => bool) internal _blocklistActivated;

  // Mapping from token to certificate activation status.
  mapping(address => CertificateValidation) internal _certificateActivated;

  enum CertificateValidation {
    None,
    NonceBased,
    SaltBased
  }

  // Mapping from (token, certificateNonce) to "used" status to ensure a certificate can be used only once
  mapping(address => mapping(address => uint256)) internal _usedCertificateNonce;

  // Mapping from (token, certificateSalt) to "used" status to ensure a certificate can be used only once
  mapping(address => mapping(bytes32 => bool)) internal _usedCertificateSalt;

  // Mapping from token to partition granularity activation status.
  mapping(address => bool) internal _granularityByPartitionActivated;

  // Mapping from token to holds activation status.
  mapping(address => bool) internal _holdsActivated;

  struct Hold {
    bytes32 partition;
    address sender;
    address recipient;
    address notary;
    uint256 value;
    uint256 expiration;
    bytes32 secretHash;
    bytes32 secret;
    HoldStatusCode status;
  }

  // Mapping from (token, partition) to partition granularity.
  mapping(address => mapping(bytes32 => uint256)) internal _granularityByPartition;
  
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

  // Mapping from hash to hold ID.
  mapping(bytes32 => bytes32) internal _holdIds;

  event HoldCreated(
    address indexed token,
    bytes32 indexed holdId,
    bytes32 partition,
    address sender,
    address recipient,
    address indexed notary,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash
  );
  event HoldReleased(address indexed token, bytes32 holdId, address indexed notary, HoldStatusCode status);
  event HoldRenewed(address indexed token, bytes32 holdId, address indexed notary, uint256 oldExpiration, uint256 newExpiration);
  event HoldExecuted(address indexed token, bytes32 holdId, address indexed notary, uint256 heldValue, uint256 transferredValue, bytes32 secret);
  event HoldExecutedAndKeptOpen(address indexed token, bytes32 holdId, address indexed notary, uint256 heldValue, uint256 transferredValue, bytes32 secret);
  
  /**
   * @dev Modifier to verify if sender is a token controller.
   */
  modifier onlyTokenController(address token) {
    require(
      msg.sender == token ||
      msg.sender == Ownable(token).owner() ||
      _isTokenController[token][msg.sender],
      "Sender is not a token controller."
    );
    _;
  }

  /**
   * @dev Modifier to verify if sender is a pauser.
   */
  modifier onlyPauser(address token) override {
    require(
      msg.sender == token ||
      msg.sender == Ownable(token).owner() ||
      _isTokenController[token][msg.sender] ||
      isPauser(token, msg.sender),
      "Sender is not a pauser"
    );
    _;
  }

  /**
   * @dev Modifier to verify if sender is a pauser.
   */
  modifier onlyCertificateSigner(address token) override {
    require(
      msg.sender == token ||
      msg.sender == Ownable(token).owner() ||
      _isTokenController[token][msg.sender] ||
      isCertificateSigner(token, msg.sender),
      "Sender is not a certificate signer"
    );
    _;
  }

  /**
   * @dev Modifier to verify if sender is an allowlist admin.
   */
  modifier onlyAllowlistAdmin(address token) override {
    require(
      msg.sender == token ||
      msg.sender == Ownable(token).owner() ||
      _isTokenController[token][msg.sender] ||
      isAllowlistAdmin(token, msg.sender),
      "Sender is not an allowlist admin"
    );
    _;
  }

  /**
   * @dev Modifier to verify if sender is a blocklist admin.
   */
  modifier onlyBlocklistAdmin(address token) override {
    require(
      msg.sender == token ||
      msg.sender == Ownable(token).owner() ||
      _isTokenController[token][msg.sender] ||
      isBlocklistAdmin(token, msg.sender),
      "Sender is not a blocklist admin"
    );
    _;
  }

  constructor() {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_VALIDATOR);


  }

  /**
   * @dev Get the list of token controllers for a given token.
   * @return Setup of a given token.
   */
  function retrieveTokenSetup(address token) external view returns (CertificateValidation, bool, bool, bool, bool, address[] memory) {
    return (
      _certificateActivated[token],
      _allowlistActivated[token],
      _blocklistActivated[token],
      _granularityByPartitionActivated[token],
      _holdsActivated[token],
      _tokenControllers[token]
    );
  }

  /**
   * @dev Register token setup.
   */
  function registerTokenSetup(
    address token,
    CertificateValidation certificateActivated,
    bool allowlistActivated,
    bool blocklistActivated,
    bool granularityByPartitionActivated,
    bool holdsActivated,
    address[] calldata operators
  ) external onlyTokenController(token) {
    _certificateActivated[token] = certificateActivated;
    _allowlistActivated[token] = allowlistActivated;
    _blocklistActivated[token] = blocklistActivated;
    _granularityByPartitionActivated[token] = granularityByPartitionActivated;
    _holdsActivated[token] = holdsActivated;
    _setTokenControllers(token, operators);
  }

  /**
   * @dev Set list of token controllers for a given token.
   * @param token Token address.
   * @param operators Operators addresses.
   */
  function _setTokenControllers(address token, address[] memory operators) internal {
    for (uint i = 0; i<_tokenControllers[token].length; i++){
      _isTokenController[token][_tokenControllers[token][i]] = false;
    }
    for (uint j = 0; j<operators.length; j++){
      _isTokenController[token][operators[j]] = true;
    }
    _tokenControllers[token] = operators;
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @param data The struct containing the validation information.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function canValidate(IERC1400TokensValidator.ValidateData calldata data) // Comments to avoid compilation warnings for unused variables.
    external
    override
    view 
    returns(bool)
  {
    (bool canValidateToken,,) = _canValidateCertificateToken(data.token, data.payload, data.operator, data.operatorData.length != 0 ? data.operatorData : data.data);

    canValidateToken = canValidateToken && _canValidateAllowlistAndBlocklistToken(data.token, data.payload, data.from, data.to);
    
    canValidateToken = canValidateToken && !paused(data.token);

    canValidateToken = canValidateToken && _canValidateGranularToken(data.token, data.partition, data.value);

    canValidateToken = canValidateToken && _canValidateHoldableToken(data.token, data.partition, data.operator, data.from, data.to, data.value);

    return canValidateToken;
  }

  /**
   * @dev Function called by the token contract before executing a transfer.
   * @param payload Payload of the initial transaction.
   * @param partition Name of the partition (left empty for ERC20 transfer).
   * @param operator Address which triggered the balance decrease (through transfer or redemption).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a redemption.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information.
   * @param operatorData Extra information, attached by the operator (if any).
   */
  function tokensToValidate(
    bytes calldata payload,
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata operatorData
  ) // Comments to avoid compilation warnings for unused variables.
    external
    override
  {
    //Local scope variables to avoid stack too deep
    {
        (bool canValidateCertificateToken, CertificateValidation certificateControl, bytes32 salt) = _canValidateCertificateToken(msg.sender, payload, operator, operatorData.length != 0 ? operatorData : data);
        require(canValidateCertificateToken, "54"); // 0x54	transfers halted (contract paused)

        _useCertificateIfActivated(msg.sender, certificateControl, operator, salt);
    }

    {
        require(_canValidateAllowlistAndBlocklistToken(msg.sender, payload, from, to), "54"); // 0x54	transfers halted (contract paused)
    }
    
    {
        require(!paused(msg.sender), "54"); // 0x54	transfers halted (contract paused)
    }
    
    {
        require(_canValidateGranularToken(msg.sender, partition, value), "50"); // 0x50	transfer failure

        require(_canValidateHoldableToken(msg.sender, partition, operator, from, to, value), "55"); // 0x55	funds locked (lockup period)
    }
    
    {
        (, bytes32 holdId) = _retrieveHoldHashId(msg.sender, partition, operator, from, to, value);
        if (_holdsActivated[msg.sender] && holdId != "") {
          Hold storage executableHold = _holds[msg.sender][holdId];
          _setHoldToExecuted(
            msg.sender,
            executableHold,
            holdId,
            value,
            executableHold.value,
            ""
          );
        }
    }
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   * @return hold ID in case a hold can be executed for the given parameters.
   */
  function _canValidateCertificateToken(
    address token,
    bytes memory payload,
    address operator,
    bytes memory certificate
  )
    internal
    view
    returns(bool, CertificateValidation, bytes32)
  {
    if(
      _certificateActivated[token] > CertificateValidation.None &&
      _functionSupportsCertificateValidation(payload) &&
      !isCertificateSigner(token, operator) &&
      address(this) != operator
    ) {
      if(_certificateActivated[token] == CertificateValidation.SaltBased) {
        (bool valid, bytes32 salt) = _checkSaltBasedCertificate(
          token,
          operator,
          payload,
          certificate
        );
        if(valid) {
          return (true, CertificateValidation.SaltBased, salt);
        } else {
          return (false, CertificateValidation.SaltBased, "");
        }
        
      } else { // case when _certificateActivated[token] == CertificateValidation.NonceBased
        if(
          _checkNonceBasedCertificate(
            token,
            operator,
            payload,
            certificate
          )
        ) {
          return (true, CertificateValidation.NonceBased, "");
        } else {
          return (false, CertificateValidation.NonceBased, "");
        }
      }
    }

    return (true, CertificateValidation.None, "");
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function _canValidateAllowlistAndBlocklistToken(
    address token,
    bytes memory payload,
    address from,
    address to
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    view
    returns(bool)
  {
    if(
      !_functionSupportsCertificateValidation(payload) ||
      _certificateActivated[token] == CertificateValidation.None
    ) {
      if(_allowlistActivated[token]) {
        if(from != address(0) && !isAllowlisted(token, from)) {
          return false;
        }
        if(to != address(0) && !isAllowlisted(token, to)) {
          return false;
        }
      }
      if(_blocklistActivated[token]) {
        if(from != address(0) && isBlocklisted(token, from)) {
          return false;
        }
        if(to != address(0) && isBlocklisted(token, to)) {
          return false;
        }
      }
    }
    
    return true;
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function _canValidateGranularToken(
    address token,
    bytes32 partition,
    uint value
  )
    internal
    view
    returns(bool)
  {
    if(_granularityByPartitionActivated[token]) {
      if(
        _granularityByPartition[token][partition] > 0 &&
        !_isMultiple(_granularityByPartition[token][partition], value)
      ) {
        return false;
      } 
    }

    return true;
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function _canValidateHoldableToken(
    address token,
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint value
  )
    internal
    view
    returns(bool)
  {
    if (_holdsActivated[token] && from != address(0)) {
      if(operator != from) {
        (, bytes32 holdId) = _retrieveHoldHashId(token, partition, operator, from, to, value);
        Hold storage hold_ = _holds[token][holdId];
        
        if (_holdCanBeExecutedAsNotary(hold_, operator, value) && value <= IERC1400(token).balanceOfByPartition(partition, from)) {
          return true;
        }
      }
      
      if(value > _spendableBalanceOfByPartition(token, partition, from)) {
        return false;
      }
    }

    return true;
  }

  /**
   * @dev Get granularity for a given partition.
   * @param token Token address.
   * @param partition Name of the partition.
   * @return Granularity of the partition.
   */
  function granularityByPartition(address token, bytes32 partition) external view returns (uint256) {
    return _granularityByPartition[token][partition];
  }
  
  /**
   * @dev Set partition granularity
   */
  function setGranularityByPartition(
    address token,
    bytes32 partition,
    uint256 granularity
  )
    external
    onlyTokenController(token)
  {
    _granularityByPartition[token][partition] = granularity;
  }

  /**
   * @dev Create a new token pre-hold.
   */
  function preHoldFor(
    address token,
    bytes32 holdId,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 timeToExpiration,
    bytes32 secretHash,
    bytes calldata certificate
  )
    external
    returns (bool)
  {
    return _createHold(
      token,
      holdId,
      address(0),
      recipient,
      notary,
      partition,
      value,
      _computeExpiration(timeToExpiration),
      secretHash,
      certificate
    );
  }

  /**
   * @dev Create a new token pre-hold with expiration date.
   */
  function preHoldForWithExpirationDate(
    address token,
    bytes32 holdId,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    bytes calldata certificate
  )
    external
    returns (bool)
  {
    _checkExpiration(expiration);

    return _createHold(
      token,
      holdId,
      address(0),
      recipient,
      notary,
      partition,
      value,
      expiration,
      secretHash,
      certificate
    );
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
    bytes calldata certificate
  ) 
    external
    returns (bool)
  {
    return _createHold(
      token,
      holdId,
      msg.sender,
      recipient,
      notary,
      partition,
      value,
      _computeExpiration(timeToExpiration),
      secretHash,
      certificate
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
    bytes calldata certificate
  )
    external
    returns (bool)
  {
    _checkExpiration(expiration);

    return _createHold(
      token,
      holdId,
      msg.sender,
      recipient,
      notary,
      partition,
      value,
      expiration,
      secretHash,
      certificate
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
    bytes calldata certificate
  )
    external
    returns (bool)
  {
    require(sender != address(0), "Payer address must not be zero address");
    return _createHold(
      token,
      holdId,
      sender,
      recipient,
      notary,
      partition,
      value,
      _computeExpiration(timeToExpiration),
      secretHash,
      certificate
    );
  }

  /**
   * @dev Create a new token hold with expiration date on behalf of the token holder.
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
    bytes calldata certificate
  )
    external
    returns (bool)
  {
    _checkExpiration(expiration);
    require(sender != address(0), "Payer address must not be zero address");

    return _createHold(
      token,
      holdId,
      sender,
      recipient,
      notary,
      partition,
      value,
      expiration,
      secretHash,
      certificate
    );
  }

  /**
   * @dev Create a new token hold.
   */
  function _createHold(
    address token,
    bytes32 holdId,
    address sender,
    address recipient,
    address notary,
    bytes32 partition,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    bytes memory certificate
  ) internal returns (bool)
  {
    Hold storage newHold = _holds[token][holdId];

    require(recipient != address(0), "Payee address must not be zero address");
    require(value != 0, "Value must be greater than zero");
    require(newHold.value == 0, "This holdId already exists");
    require(
      _canHoldOrCanPreHold(token, msg.sender, sender, certificate),
      "A hold can only be created with adapted authorizations"
    );
    
    if (sender != address(0)) { // hold (tokens already exist)
      require(value <= _spendableBalanceOfByPartition(token, partition, sender), "Amount of the hold can't be greater than the spendable balance of the sender");
    }
    
    newHold.partition = partition;
    newHold.sender = sender;
    newHold.recipient = recipient;
    newHold.notary = notary;
    newHold.value = value;
    newHold.expiration = expiration;
    newHold.secretHash = secretHash;
    newHold.status = HoldStatusCode.Ordered;

    if(sender != address(0)) {
      // In case tokens already exist, increase held balance
      _increaseHeldBalance(token, newHold, holdId);

      (bytes32 holdHash,) = _retrieveHoldHashId(
        token, newHold.partition,
        newHold.notary,
        newHold.sender,
        newHold.recipient,
        newHold.value
      );

      _holdIds[holdHash] = holdId;
    }

    emit HoldCreated(
      token,
      holdId,
      partition,
      sender,
      recipient,
      notary,
      value,
      expiration,
      secretHash
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

    if(releasableHold.sender != address(0)) { // In case tokens already exist, decrease held balance
      _decreaseHeldBalance(token, releasableHold, releasableHold.value);

      (bytes32 holdHash,) = _retrieveHoldHashId(
        token, releasableHold.partition,
        releasableHold.notary,
        releasableHold.sender,
        releasableHold.recipient,
        releasableHold.value
      );

      delete _holdIds[holdHash];
    }

    emit HoldReleased(token, holdId, releasableHold.notary, releasableHold.status);

    return true;
  }

  /**
   * @dev Renew hold.
   */
  function renewHold(address token, bytes32 holdId, uint256 timeToExpiration, bytes calldata certificate) external returns (bool) {
    return _renewHold(token, holdId, _computeExpiration(timeToExpiration), certificate);
  }

  /**
   * @dev Renew hold with expiration time.
   */
  function renewHoldWithExpirationDate(address token, bytes32 holdId, uint256 expiration, bytes calldata certificate) external returns (bool) {
    _checkExpiration(expiration);

    return _renewHold(token, holdId, expiration, certificate);
  }

  /**
   * @dev Renew hold.
   */
  function _renewHold(address token, bytes32 holdId, uint256 expiration, bytes memory certificate) internal returns (bool) {
    Hold storage renewableHold = _holds[token][holdId];

    require(
      renewableHold.status == HoldStatusCode.Ordered
      || renewableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
      "A hold can only be renewed in status Ordered or ExecutedAndKeptOpen"
    );
    require(!_isExpired(renewableHold.expiration), "An expired hold can not be renewed");

    require(
      _canHoldOrCanPreHold(token, msg.sender, renewableHold.sender, certificate),
      "A hold can only be renewed with adapted authorizations"
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
  function executeHold(address token, bytes32 holdId, uint256 value, bytes32 secret) external override {
    _executeHold(
      token,
      holdId,
      msg.sender,
      value,
      secret,
      false
    );
  }

  /**
   * @dev Execute hold and keep open.
   */
  function executeHoldAndKeepOpen(address token, bytes32 holdId, uint256 value, bytes32 secret) external {
    _executeHold(
      token,
      holdId,
      msg.sender,
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
    address operator,
    uint256 value,
    bytes32 secret,
    bool keepOpenIfHoldHasBalance
  ) internal
  {
    Hold storage executableHold = _holds[token][holdId];

    bool canExecuteHold;
    if(secret != "" && _holdCanBeExecutedAsSecretHolder(executableHold, value, secret)) {
      executableHold.secret = secret;
      canExecuteHold = true;
    } else if(_holdCanBeExecutedAsNotary(executableHold, operator, value)) {
      canExecuteHold = true;
    }

    if(canExecuteHold) {
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

      if (executableHold.sender == address(0)) { // pre-hold (tokens do not already exist)
        IERC1400(token).issueByPartition(executableHold.partition, executableHold.recipient, value, "");
      } else { // post-hold (tokens already exist)
        IERC1400(token).operatorTransferByPartition(executableHold.partition, executableHold.sender, executableHold.recipient, value, "", "");
      }
      
    } else {
      revert("hold can not be executed");
    }

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
    if(executableHold.sender != address(0)) { // In case tokens already exist, decrease held balance
      _decreaseHeldBalance(token, executableHold, heldBalanceDecrease);
    }

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
    if(executableHold.sender != address(0)) { // In case tokens already exist, decrease held balance
      _decreaseHeldBalance(token, executableHold, heldBalanceDecrease);
    } 

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
  function _increaseHeldBalance(address token, Hold storage executableHold, bytes32/*holdId*/) private {
    _heldBalance[token][executableHold.sender] = _heldBalance[token][executableHold.sender].add(executableHold.value);
    _totalHeldBalance[token] = _totalHeldBalance[token].add(executableHold.value);

    _heldBalanceByPartition[token][executableHold.sender][executableHold.partition] = _heldBalanceByPartition[token][executableHold.sender][executableHold.partition].add(executableHold.value);
    _totalHeldBalanceByPartition[token][executableHold.partition] = _totalHeldBalanceByPartition[token][executableHold.partition].add(executableHold.value);
  }

  /**
   * @dev Decrease held balance.
   */
  function _decreaseHeldBalance(address token, Hold storage executableHold, uint256 value) private {
    _heldBalance[token][executableHold.sender] = _heldBalance[token][executableHold.sender].sub(value);
    _totalHeldBalance[token] = _totalHeldBalance[token].sub(value);

    _heldBalanceByPartition[token][executableHold.sender][executableHold.partition] = _heldBalanceByPartition[token][executableHold.sender][executableHold.partition].sub(value);
    _totalHeldBalanceByPartition[token][executableHold.partition] = _totalHeldBalanceByPartition[token][executableHold.partition].sub(value);
  }

  /**
   * @dev Check secret.
   */
  function _checkSecret(Hold storage executableHold, bytes32 secret) internal view returns (bool) {
    if(executableHold.secretHash == sha256(abi.encodePacked(secret))) {
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
        expiration = block.timestamp.add(timeToExpiration);
    }

    return expiration;
  }

  /**
   * @dev Check expiration time.
   */
  function _checkExpiration(uint256 expiration) private view {
    require(expiration > block.timestamp || expiration == 0, "Expiration date must be greater than block timestamp or zero");
  }

  /**
   * @dev Check is expiration date is past.
   */
  function _isExpired(uint256 expiration) internal view returns (bool) {
    return expiration != 0 && (block.timestamp >= expiration);
  }

  /**
   * @dev Retrieve hold hash, and ID for given parameters
   */
  function _retrieveHoldHashId(address token, bytes32 partition, address notary, address sender, address recipient, uint value) internal view returns (bytes32, bytes32) {
    // Pack and hash hold parameters
    bytes32 holdHash = keccak256(abi.encodePacked(
      token,
      partition,
      sender,
      recipient,
      notary,
      value
    ));
    bytes32 holdId = _holdIds[holdHash];

    return (holdHash, holdId);
  }  

  /**
   * @dev Check if hold can be executed
   */
  function _holdCanBeExecuted(Hold storage executableHold, uint value) internal view returns (bool) {
    if(!(executableHold.status == HoldStatusCode.Ordered || executableHold.status == HoldStatusCode.ExecutedAndKeptOpen)) {
      return false; // A hold can only be executed in status Ordered or ExecutedAndKeptOpen
    } else if(value == 0) {
      return false; // Value must be greater than zero
    } else if(_isExpired(executableHold.expiration)) {
      return false; // The hold has already expired
    } else if(value > executableHold.value) {
      return false; // The value should be equal or less than the held amount
    } else {
      return true;
    }
  }

  /**
   * @dev Check if hold can be executed as secret holder
   */
  function _holdCanBeExecutedAsSecretHolder(Hold storage executableHold, uint value, bytes32 secret) internal view returns (bool) {
    if(
      _checkSecret(executableHold, secret)
      && _holdCanBeExecuted(executableHold, value)) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Check if hold can be executed as notary
   */
  function _holdCanBeExecutedAsNotary(Hold storage executableHold, address operator, uint value) internal view returns (bool) {
    if(
      executableHold.notary == operator
      && _holdCanBeExecuted(executableHold, value)) {
      return true;
    } else {
      return false;
    }
  }  

  /**
   * @dev Retrieve hold data.
   */
  function retrieveHoldData(address token, bytes32 holdId) external override view returns (
    bytes32 partition,
    address sender,
    address recipient,
    address notary,
    uint256 value,
    uint256 expiration,
    bytes32 secretHash,
    bytes32 secret,
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

  /**
   * @dev Check if hold (or pre-hold) can be created.
   * @return 'true' if the operator can create pre-holds, 'false' if not.
   */
  function _canHoldOrCanPreHold(address token, address operator, address sender, bytes memory certificate) internal returns(bool) { 
    (bool canValidateCertificate, CertificateValidation certificateControl, bytes32 salt) = _canValidateCertificateToken(token, msg.data, operator, certificate);
    _useCertificateIfActivated(token, certificateControl, operator, salt);

    if (sender != address(0)) { // hold
      return canValidateCertificate && (_isTokenController[token][operator] || operator == sender);
    } else { // pre-hold
      return canValidateCertificate && IMinterRole(token).isMinter(operator); 
    }
  }

  /**
   * @dev Check if validator is activated for the function called in the smart contract.
   * @param payload Payload of the initial transaction.
   * @return 'true' if the function requires validation, 'false' if not.
   */
  function _functionSupportsCertificateValidation(bytes memory payload) internal pure returns(bool) {
    bytes4 functionSig = _getFunctionSig(payload);
    if(functionSig == ERC20_TRANSFER_ID || functionSig == ERC20_TRANSFERFROM_ID) {
      return false;
    } else {
      return true;
    }
  }

  /**
   * @dev Use certificate, if validated.
   * @param token Token address.
   * @param certificateControl Type of certificate.
   * @param msgSender Transaction sender (only for nonce-based certificates).
   * @param salt Salt extracted from the certificate (only for salt-based certificates).
   */
  function _useCertificateIfActivated(address token, CertificateValidation certificateControl, address msgSender, bytes32 salt) internal {
    // Declare certificate as used
    if (certificateControl == CertificateValidation.NonceBased) {
      _usedCertificateNonce[token][msgSender] += 1;
    } else if (certificateControl == CertificateValidation.SaltBased) {
      _usedCertificateSalt[token][salt] = true;
    }
  }

  /**
   * @dev Extract function signature from payload.
   * @param payload Payload of the initial transaction.
   * @return Function signature.
   */
  function _getFunctionSig(bytes memory payload) internal pure returns(bytes4) {
    return (bytes4(payload[0]) | bytes4(payload[1]) >> 8 | bytes4(payload[2]) >> 16 | bytes4(payload[3]) >> 24);
  }

  /**
   * @dev Check if 'value' is multiple of 'granularity'.
   * @param granularity The granularity that want's to be checked.
   * @param value The quantity that want's to be checked.
   * @return 'true' if 'value' is a multiple of 'granularity'.
   */
  function _isMultiple(uint256 granularity, uint256 value) internal pure returns(bool) {
    return(value.div(granularity).mul(granularity) == value);
  }

  /**
   * @dev Get state of certificate (used or not).
   * @param token Token address.
   * @param sender Address whom to check the counter of.
   * @return uint256 Number of transaction already sent for this token contract.
   */
  function usedCertificateNonce(address token, address sender) external view returns (uint256) {
    return _usedCertificateNonce[token][sender];
  }

  /**
   * @dev Checks if a nonce-based certificate is correct
   * @param certificate Certificate to control
   */
  function _checkNonceBasedCertificate(
    address token,
    address msgSender,
    bytes memory payloadWithCertificate,
    bytes memory certificate
  )
    internal
    view
    returns(bool)
  {
    // Certificate should be 97 bytes long
    if (certificate.length != 97) {
      return false;
    }

    uint256 e;
    uint8 v;

    // Extract certificate information and expiration time from payload
    assembly {
      // Retrieve expirationTime & ECDSA element (v) from certificate which is a 97 long bytes
      // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
      e := mload(add(certificate, 0x20))
      v := byte(0, mload(add(certificate, 0x80)))
    }

    // Certificate should not be expired
    if (e < block.timestamp) {
      return false;
    }

    if (v < 27) {
      v += 27;
    }

    // Perform ecrecover to ensure message information corresponds to certificate
    if (v == 27 || v == 28) {
      // Extract certificate from payload
      bytes memory payloadWithoutCertificate = new bytes(payloadWithCertificate.length.sub(160));
      for (uint i = 0; i < payloadWithCertificate.length.sub(160); i++) { // replace 4 bytes corresponding to function selector
        payloadWithoutCertificate[i] = payloadWithCertificate[i];
      }

      // Pack and hash
      bytes memory pack = abi.encodePacked(
        msgSender,
        token,
        payloadWithoutCertificate,
        e,
        _usedCertificateNonce[token][msgSender]
      );
      bytes32 hash = keccak256(
        abi.encodePacked(
          DomainAware(token).generateDomainSeparator(),
          keccak256(pack)
        )
      );

      bytes32 r;
      bytes32 s;
      // Extract certificate information and expiration time from payload
      assembly {
        // Retrieve ECDSA elements (r, s) from certificate which is a 97 long bytes
        // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
        r := mload(add(certificate, 0x40))
        s := mload(add(certificate, 0x60))
      }

      // Check if certificate match expected transactions parameters
      if (isCertificateSigner(token, ecrecover(hash, v, r, s))) {
        return true;
      }
    }
    return false;
  }

  /**
   * @dev Get state of certificate (used or not).
   * @param token Token address.
   * @param salt First 32 bytes of certificate whose validity is being checked.
   * @return bool 'true' if certificate is already used, 'false' if not.
   */
  function usedCertificateSalt(address token, bytes32 salt) external view returns (bool) {
    return _usedCertificateSalt[token][salt];
  }

  /**
   * @dev Checks if a salt-based certificate is correct
   * @param certificate Certificate to control
   */
  function _checkSaltBasedCertificate(
    address token,
    address msgSender,
    bytes memory payloadWithCertificate,
    bytes memory certificate
  )
    internal
    view
    returns(bool, bytes32)
  {
    // Certificate should be 129 bytes long
    if (certificate.length != 129) {
      return (false, "");
    }

    bytes32 salt;
    uint256 e;
    uint8 v;

    // Extract certificate information and expiration time from payload
    assembly {
      // Retrieve expirationTime & ECDSA elements from certificate which is a 97 long bytes
      // Certificate encoding format is: <salt (32 bytes)>@<expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
      salt := mload(add(certificate, 0x20))
      e := mload(add(certificate, 0x40))
      v := byte(0, mload(add(certificate, 0xa0)))
    }

    // Certificate should not be expired
    if (e < block.timestamp) {
      return (false, "");
    }

    if (v < 27) {
      v += 27;
    }

    // Perform ecrecover to ensure message information corresponds to certificate
    if (v == 27 || v == 28) {
      // Extract certificate from payload
      bytes memory payloadWithoutCertificate = new bytes(payloadWithCertificate.length.sub(192));
      for (uint i = 0; i < payloadWithCertificate.length.sub(192); i++) { // replace 4 bytes corresponding to function selector
        payloadWithoutCertificate[i] = payloadWithCertificate[i];
      }

      // Pack and hash
      bytes memory pack = abi.encodePacked(
        msgSender,
        token,
        payloadWithoutCertificate,
        e,
        salt
      );

      bytes32 hash = keccak256(
        abi.encodePacked(
          DomainAware(token).generateDomainSeparator(),
          keccak256(pack)
        )
      );

      bytes32 r;
      bytes32 s;
      // Extract certificate information and expiration time from payload
      assembly {
        // Retrieve ECDSA elements (r, s) from certificate which is a 97 long bytes
        // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
        r := mload(add(certificate, 0x60))
        s := mload(add(certificate, 0x80))
      }

      // Check if certificate match expected transactions parameters
      if (isCertificateSigner(token, ecrecover(hash, v, r, s)) && !_usedCertificateSalt[token][salt]) {
        return (true, salt);
      }
    }
    return (false, "");
  }
}