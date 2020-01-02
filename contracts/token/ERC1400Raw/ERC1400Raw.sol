/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "erc1820/contracts/ERC1820Client.sol";
import "../ERC1820/ERC1820Implementer.sol";


import "../../CertificateController/CertificateController.sol";

import "./IERC1400Raw.sol";
import "./IERC1400TokensSender.sol";
import "./IERC1400TokensValidator.sol";
import "./IERC1400TokensRecipient.sol";


/**
 * @title ERC1400Raw
 * @dev ERC1400Raw logic
 */
contract ERC1400Raw is IERC1400Raw, Ownable, ERC1820Client, ERC1820Implementer, CertificateController {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_SENDER = "ERC1400TokensSender";
  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";
  string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

  string internal _name;
  string internal _symbol;
  uint256 internal _granularity;
  uint256 internal _totalSupply;

  bool internal _migrated;

  // Indicate whether the token can still be controlled by operators or not anymore.
  bool internal _isControllable;

  // Mapping from tokenHolder to balance.
  mapping(address => uint256) internal _balances;

  /******************** Mappings related to operator **************************/
  // Mapping from (operator, tokenHolder) to authorized status. [TOKEN-HOLDER-SPECIFIC]
  mapping(address => mapping(address => bool)) internal _authorizedOperator;

  // Array of controllers. [GLOBAL - NOT TOKEN-HOLDER-SPECIFIC]
  address[] internal _controllers;

  // Mapping from operator to controller status. [GLOBAL - NOT TOKEN-HOLDER-SPECIFIC]
  mapping(address => bool) internal _isController;
  /****************************************************************************/

  /**
   * @dev Modifier to make a function callable only when the contract is not migrated.
   */
  modifier whenNotMigrated() {
      require(!_migrated, "A8");
      _;
  }

  /**
   * [ERC1400Raw CONSTRUCTOR]
   * @dev Initialize ERC1400Raw and CertificateController parameters + register
   * the contract implementation in ERC1820Registry.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, issuance,
   * redemption (Cf. CertificateController.sol).
   */
  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    address certificateSigner
  )
    public
    CertificateController(certificateSigner)
  {
    _name = name;
    _symbol = symbol;
    _totalSupply = 0;
    require(granularity >= 1); // Constructor Blocked - Token granularity can not be lower than 1
    _granularity = granularity;

    _setControllers(controllers);
  }

  /********************** ERC1400Raw EXTERNAL FUNCTIONS ***************************/

  /**
   * [ERC1400Raw INTERFACE (1/13)]
   * @dev Get the name of the token, e.g., "MyToken".
   * @return Name of the token.
   */
  function name() external view returns(string memory) {
    return _name;
  }

  /**
   * [ERC1400Raw INTERFACE (2/13)]
   * @dev Get the symbol of the token, e.g., "MYT".
   * @return Symbol of the token.
   */
  function symbol() external view returns(string memory) {
    return _symbol;
  }

  /**
   * [ERC1400Raw INTERFACE (3/13)]
   * @dev Get the total number of issued tokens.
   * @return Total supply of tokens currently in circulation.
   */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /**
   * [ERC1400Raw INTERFACE (4/13)]
   * @dev Get the balance of the account with address 'tokenHolder'.
   * @param tokenHolder Address for which the balance is returned.
   * @return Amount of token held by 'tokenHolder' in the token contract.
   */
  function balanceOf(address tokenHolder) external view returns (uint256) {
    return _balances[tokenHolder];
  }

  /**
   * [ERC1400Raw INTERFACE (5/13)]
   * @dev Get the smallest part of the token that’s not divisible.
   * @return The smallest non-divisible part of the token.
   */
  function granularity() external view returns(uint256) {
    return _granularity;
  }

  /**
   * [ERC1400Raw INTERFACE (6/13)]
   * @dev Get the list of controllers as defined by the token contract.
   * @return List of addresses of all the controllers.
   */
  function controllers() external view returns (address[] memory) {
    return _controllers;
  }

  /**
   * [ERC1400Raw INTERFACE (7/13)]
   * @dev Set a third party operator address as an operator of 'msg.sender' to transfer
   * and redeem tokens on its behalf.
   * @param operator Address to set as an operator for 'msg.sender'.
   */
  function authorizeOperator(address operator) external {
    require(operator != msg.sender);
    _authorizedOperator[operator][msg.sender] = true;
    emit AuthorizedOperator(operator, msg.sender);
  }

  /**
   * [ERC1400Raw INTERFACE (8/13)]
   * @dev Remove the right of the operator address to be an operator for 'msg.sender'
   * and to transfer and redeem tokens on its behalf.
   * @param operator Address to rescind as an operator for 'msg.sender'.
   */
  function revokeOperator(address operator) external {
    require(operator != msg.sender);
    _authorizedOperator[operator][msg.sender] = false;
    emit RevokedOperator(operator, msg.sender);
  }

  /**
   * [ERC1400Raw INTERFACE (9/13)]
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of tokenHolder.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator.
   * @return 'true' if operator is an operator of 'tokenHolder' and 'false' otherwise.
   */
  function isOperator(address operator, address tokenHolder) external view returns (bool) {
    return _isOperator(operator, tokenHolder);
  }

  /**
   * [ERC1400Raw INTERFACE (10/13)]
   * @dev Transfer the amount of tokens from the address 'msg.sender' to the address 'to'.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function transferWithData(address to, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    _callPreTransferHooks("", msg.sender, msg.sender, to, value, data, "");

    _transferWithData(msg.sender, msg.sender, to, value, data, "");

    _callPostTransferHooks("", msg.sender, msg.sender, to, value, data, "", true);
  }

  /**
   * [ERC1400Raw INTERFACE (11/13)]
   * @dev Transfer the amount of tokens on behalf of the address 'from' to the address 'to'.
   * @param from Token holder (or 'address(0)' to set from to 'msg.sender').
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, and intended for the token holder ('from').
   * @param operatorData Information attached to the transfer by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function transferFromWithData(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData)
    external
    isValidCertificate(operatorData)
  {
    require(_isOperator(msg.sender, from), "A7"); // Transfer Blocked - Identity restriction

    _callPreTransferHooks("", msg.sender, from, to, value, data, operatorData);

    _transferWithData(msg.sender, from, to, value, data, operatorData);

    _callPostTransferHooks("", msg.sender, from, to, value, data, operatorData, true);
  }

  /**
   * [ERC1400Raw INTERFACE (12/13)]
   * @dev Redeem the amount of tokens from the address 'msg.sender'.
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function redeem(uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    _callPreTransferHooks("", msg.sender, msg.sender, address(0), value, data, "");

    _redeem(msg.sender, msg.sender, value, data, "");
  }

  /**
   * [ERC1400Raw INTERFACE (13/13)]
   * @dev Redeem the amount of tokens on behalf of the address from.
   * @param from Token holder whose tokens will be redeemed (or address(0) to set from to msg.sender).
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption, by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function redeemFrom(address from, uint256 value, bytes calldata data, bytes calldata operatorData)
    external
    isValidCertificate(operatorData)
  {
    require(_isOperator(msg.sender, from), "A7"); // Transfer Blocked - Identity restriction

    _callPreTransferHooks("", msg.sender, from, address(0), value, data, operatorData);

    _redeem(msg.sender, from, value, data, operatorData);
  }

  /********************** ERC1400Raw INTERNAL FUNCTIONS ***************************/

  /**
   * [INTERNAL]
   * @dev Check if 'value' is multiple of the granularity.
   * @param value The quantity that want's to be checked.
   * @return 'true' if 'value' is a multiple of the granularity.
   */
  function _isMultiple(uint256 value) internal view returns(bool) {
    return(value.div(_granularity).mul(_granularity) == value);
  }

  /**
   * [INTERNAL]
   * @dev Check whether an address is a regular address or not.
   * @param addr Address of the contract that has to be checked.
   * @return 'true' if 'addr' is a regular address (not a contract).
   */
  function _isRegularAddress(address addr) internal view returns(bool) {
    if (addr == address(0)) { return false; }
    uint size;
    assembly { size := extcodesize(addr) } // solhint-disable-line no-inline-assembly
    return size == 0;
  }

  /**
   * [INTERNAL]
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of 'tokenHolder'.
   * @param tokenHolder Address of a token holder which may have the 'operator' address as an operator.
   * @return 'true' if 'operator' is an operator of 'tokenHolder' and 'false' otherwise.
   */
  function _isOperator(address operator, address tokenHolder) internal view returns (bool) {
    return (operator == tokenHolder
      || _authorizedOperator[operator][tokenHolder]
      || (_isControllable && _isController[operator])
    );
  }

   /**
    * [INTERNAL]
    * @dev Perform the transfer of tokens.
    * @param operator The address performing the transfer.
    * @param from Token holder.
    * @param to Token recipient.
    * @param value Number of tokens to transfer.
    * @param data Information attached to the transfer.
    * @param operatorData Information attached to the transfer by the operator (if any)..
    */
  function _transferWithData(
    address operator,
    address from,
    address to,
    uint256 value,
    bytes memory data,
    bytes memory operatorData
  )
    internal
    whenNotMigrated
  {
    require(_isMultiple(value), "A9"); // Transfer Blocked - Token granularity
    require(to != address(0), "A6"); // Transfer Blocked - Receiver not eligible
    require(_balances[from] >= value, "A4"); // Transfer Blocked - Sender balance insufficient
  
    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);

    emit TransferWithData(operator, from, to, value, data, operatorData);
  }

  /**
   * [INTERNAL]
   * @dev Perform the token redemption.
   * @param operator The address performing the redemption.
   * @param from Token holder whose tokens will be redeemed.
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption, by the operator (if any).
   */
  function _redeem(address operator, address from, uint256 value, bytes memory data, bytes memory operatorData)
    internal
    whenNotMigrated
  {
    require(_isMultiple(value), "A9"); // Transfer Blocked - Token granularity
    require(from != address(0), "A5"); // Transfer Blocked - Sender not eligible
    require(_balances[from] >= value, "A4"); // Transfer Blocked - Sender balance insufficient

    _balances[from] = _balances[from].sub(value);
    _totalSupply = _totalSupply.sub(value);

    emit Redeemed(operator, from, value, data, operatorData);
  }

  /**
   * [INTERNAL]
   * @dev Check for 'ERC1400TokensSender' hook on the sender + check for 'ERC1400TokensValidator' on the token
   * contract address and call them.
   * @param partition Name of the partition (bytes32 to be left empty for ERC1400Raw transfer).
   * @param operator Address which triggered the balance decrease (through transfer or redemption).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a redemption.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information.
   * @param operatorData Extra information, attached by the operator (if any).
   */
  function _callPreTransferHooks(
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint256 value,
    bytes memory data,
    bytes memory operatorData
  )
    internal
  {
    address senderImplementation;
    senderImplementation = interfaceAddr(from, ERC1400_TOKENS_SENDER);
    if (senderImplementation != address(0)) {
      IERC1400TokensSender(senderImplementation).tokensToTransfer(msg.sig, partition, operator, from, to, value, data, operatorData);
    }

    address validatorImplementation;
    validatorImplementation = interfaceAddr(address(this), ERC1400_TOKENS_VALIDATOR);
    if (validatorImplementation != address(0)) {
      IERC1400TokensValidator(validatorImplementation).tokensToValidate(msg.sig, partition, operator, from, to, value, data, operatorData);
    }
  }

  /**
   * [INTERNAL]
   * @dev Check for 'ERC1400TokensRecipient' hook on the recipient and call it.
   * May throw according to 'preventLocking'.
   * @param partition Name of the partition (bytes32 to be left empty for ERC1400Raw transfer).
   * @param operator Address which triggered the balance increase (through transfer or issuance).
   * @param from Token holder for a transfer and 0x for an issuance.
   * @param to Token recipient.
   * @param value Number of tokens the recipient balance is increased by.
   * @param data Extra information, intended for the token holder ('from').
   * @param operatorData Extra information attached by the operator (if any).
   * @param preventLocking 'true' if you want this function to throw when tokens are sent to a contract not
   * implementing 'ERC1400TokensRecipient'.
   * ERC1400Raw native transfer functions MUST set this parameter to 'true', and backwards compatible ERC20 transfer
   * functions SHOULD set this parameter to 'false'.
   */
  function _callPostTransferHooks(
    bytes32 partition,
    address operator,
    address from,
    address to,
    uint256 value,
    bytes memory data,
    bytes memory operatorData,
    bool preventLocking
  )
    internal
  {
    address recipientImplementation;
    recipientImplementation = interfaceAddr(to, ERC1400_TOKENS_RECIPIENT);

    if (recipientImplementation != address(0)) {
      IERC1400TokensRecipient(recipientImplementation).tokensReceived(msg.sig, partition, operator, from, to, value, data, operatorData);
    } else if (preventLocking) {
      require(_isRegularAddress(to), "A6"); // Transfer Blocked - Receiver not eligible
    }
  }

  /**
   * [INTERNAL]
   * @dev Perform the issuance of tokens.
   * @param operator Address which triggered the issuance.
   * @param to Token recipient.
   * @param value Number of tokens issued.
   * @param data Information attached to the issuance, and intended for the recipient (to).
   * @param operatorData Information attached to the issuance by the operator (if any).
   */
  function _issue(address operator, address to, uint256 value, bytes memory data, bytes memory operatorData)
    internal
    whenNotMigrated  
  {
    require(_isMultiple(value), "A9"); // Transfer Blocked - Token granularity
    require(to != address(0), "A6"); // Transfer Blocked - Receiver not eligible

    _totalSupply = _totalSupply.add(value);
    _balances[to] = _balances[to].add(value);

    emit Issued(operator, to, value, data, operatorData);
  }

  /********************** ERC1400Raw OPTIONAL FUNCTIONS ***************************/

  /**
   * [NOT MANDATORY FOR ERC1400Raw STANDARD]
   * @dev Set validator contract address.
   * The validator contract needs to verify "ERC1400TokensValidator" interface.
   * Once setup, the validator will be called everytime a transfer is executed.
   * @param validatorAddress Address of the validator contract.
   * @param interfaceLabel Interface label of hook contract.
   */
  function _setHookContract(address validatorAddress, string memory interfaceLabel) internal {
    ERC1820Client.setInterfaceImplementation(interfaceLabel, validatorAddress);
  }

  /**
   * [NOT MANDATORY FOR ERC1400Raw STANDARD]
   * @dev Set list of token controllers.
   * @param operators Controller addresses.
   */
  function _setControllers(address[] memory operators) internal {
    for (uint i = 0; i<_controllers.length; i++){
      _isController[_controllers[i]] = false;
    }
    for (uint j = 0; j<operators.length; j++){
      _isController[operators[j]] = true;
    }
    _controllers = operators;
  }

}
