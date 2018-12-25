/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "erc820/contracts/ERC820Client.sol";

import "contract-certificate-controller/contracts/CertificateController.sol";

import "./IERC777.sol";
import "./IERC777TokensSender.sol";
import "./IERC777TokensRecipient.sol";

/**
 * @title ERC777
 * @dev ERC777 logic
 */
contract ERC777 is IERC777, Ownable, ERC820Client, CertificateController {
  using SafeMath for uint256;

  string internal _name;
  string internal _symbol;
  uint256 internal _granularity;
  uint256 internal _totalSupply;

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
   * @dev Modifier to verify if token is controllable.
   */
  modifier controllableToken() {
    require(_isControllable, "A8: Transfer Blocked - Token restriction");
    _;
  }

  /**
   * [ERC777 CONSTRUCTOR]
   * @dev Initialize ERC777 and CertificateController parameters + register
   * the contract implementation in ERC820Registry.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, mint,
   * burn (Cf. CertificateController.sol).
   */
  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner
  )
    public
    CertificateController(certificateSigner)
  {
    _name = name;
    _symbol = symbol;
    _totalSupply = 0;
    require(granularity >= 1, "Constructor Blocked - Token granularity can not be lower than 1");
    _granularity = granularity;

    for (uint i = 0; i < controllers.length; i++) {
      _addController(controllers[i]);
    }

    setInterfaceImplementation("ERC777Token", this);
  }

  /********************** ERC777 EXTERNAL FUNCTIONS ***************************/

  /**
   * [ERC777 INTERFACE (1/13)]
   * @dev Get the name of the token, e.g., "MyToken".
   * @return Name of the token.
   */
  function name() external view returns(string) {
    return _name;
  }

  /**
   * [ERC777 INTERFACE (2/13)]
   * @dev Get the symbol of the token, e.g., "MYT".
   * @return Symbol of the token.
   */
  function symbol() external view returns(string) {
    return _symbol;
  }

  /**
   * [ERC777 INTERFACE (3/13)]
   * @dev Get the total number of minted tokens.
   * @return Total supply of tokens currently in circulation.
   */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /**
   * [ERC777 INTERFACE (4/13)]
   * @dev Get the balance of the account with address 'tokenHolder'.
   * @param tokenHolder Address for which the balance is returned.
   * @return Amount of token held by 'tokenHolder' in the token contract.
   */
  function balanceOf(address tokenHolder) external view returns (uint256) {
    return _balances[tokenHolder];
  }

  /**
   * [ERC777 INTERFACE (5/13)]
   * @dev Get the smallest part of the token that’s not divisible.
   * @return The smallest non-divisible part of the token.
   */
  function granularity() external view returns(uint256) {
    return _granularity;
  }

  /**
   * [ERC777 INTERFACE (6/13)]
   * @dev Get the list of controllers as defined by the token contract.
   * @return List of addresses of all the controllers.
   */
  function controllers() external view returns (address[]) {
    return _controllers;
  }

  /**
   * [ERC777 INTERFACE (7/13)]
   * @dev Set a third party operator address as an operator of 'msg.sender' to transfer
   * and burn tokens on its behalf.
   * @param operator Address to set as an operator for 'msg.sender'.
   */
  function authorizeOperator(address operator) external {
    _authorizedOperator[operator][msg.sender] = true;
    emit AuthorizedOperator(operator, msg.sender);
  }

  /**
   * [ERC777 INTERFACE (8/13)]
   * @dev Remove the right of the operator address to be an operator for 'msg.sender'
   * and to transfer and burn tokens on its behalf.
   * @param operator Address to rescind as an operator for 'msg.sender'.
   */
  function revokeOperator(address operator) external {
    _authorizedOperator[operator][msg.sender] = false;
    emit RevokedOperator(operator, msg.sender);
  }

  /**
   * [ERC777 INTERFACE (9/13)]
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of tokenHolder.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator.
   * @return 'true' if operator is an operator of 'tokenHolder' and 'false' otherwise.
   */
  function isOperatorFor(address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorFor(operator, tokenHolder);
  }

  /**
   * [ERC777 INTERFACE (10/13)]
   * @dev Transfer the amount of tokens from the address 'msg.sender' to the address 'to'.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function transferWithData(address to, uint256 value, bytes data)
    external
    isValidCertificate(data)
  {
    _transferWithData(msg.sender, msg.sender, to, value, data, "", true);
  }

  /**
   * [ERC777 INTERFACE (11/13)]
   * @dev Transfer the amount of tokens on behalf of the address 'from' to the address 'to'.
   * @param from Token holder (or 'address(0)' to set from to 'msg.sender').
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, and intended for the token holder ('from').
   * @param operatorData Information attached to the transfer by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function transferFromWithData(address from, address to, uint256 value, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    _transferWithData(msg.sender, _from, to, value, data, operatorData, true);
  }

  /**
   * [ERC777 INTERFACE (12/13)]
   * @dev Burn the amount of tokens from the address 'msg.sender'.
   * @param value Number of tokens to burn.
   * @param data Information attached to the burn, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function burn(uint256 value, bytes data)
    external
    isValidCertificate(data)
  {
    _burn(msg.sender, msg.sender, value, data, "");
  }

  /**
   * [ERC777 INTERFACE (13/13)]
   * @dev Burn the amount of tokens on behalf of the address from.
   * @param from Token holder whose tokens will be burned (or address(0) to set from to msg.sender).
   * @param value Number of tokens to burn.
   * @param data Information attached to the burn, and intended for the token holder (from).
   * @param operatorData Information attached to the burn by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function operatorBurn(address from, uint256 value, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    _burn(msg.sender, _from, value, data, operatorData);
  }

  /********************** ERC777 INTERNAL FUNCTIONS ***************************/

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
  function _isOperatorFor(address operator, address tokenHolder) internal view returns (bool) {
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
    * @param data Information attached to the transfer, and intended for the token holder ('from').
    * @param operatorData Information attached to the transfer by the operator.
    * @param preventLocking 'true' if you want this function to throw when tokens are sent to a contract not
    * implementing 'erc777tokenHolder'.
    * ERC777 native transfer functions MUST set this parameter to 'true', and backwards compatible ERC20 transfer
    * functions SHOULD set this parameter to 'false'.
    */
  function _transferWithData(
    address operator,
    address from,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData,
    bool preventLocking
  )
    internal
  {
    require(_isMultiple(value), "A9: Transfer Blocked - Token granularity");
    require(to != address(0), "A6: Transfer Blocked - Receiver not eligible");
    require(_balances[from] >= value, "A4: Transfer Blocked - Sender balance insufficient");

    _callSender(operator, from, to, value, data, operatorData);

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);

    _callRecipient(operator, from, to, value, data, operatorData, preventLocking);

    emit Sent(operator, from, to, value, data, operatorData);
  }

  /**
   * [INTERNAL]
   * @dev Perform the burning of tokens.
   * @param operator The address performing the burn.
   * @param from Token holder whose tokens will be burned.
   * @param value Number of tokens to burn.
   * @param data Information attached to the burn, and intended for the token holder ('from').
   * @param operatorData Information attached to the burn by the operator (if any).
   */
  function _burn(address operator, address from, uint256 value, bytes data, bytes operatorData)
    internal
  {
    require(_isMultiple(value), "A9: Transfer Blocked - Token granularity");
    require(from != address(0), "A5: Transfer Blocked - Sender not eligible");
    require(_balances[from] >= value, "A4: Transfer Blocked - Sender balance insufficient");

    _callSender(operator, from, address(0), value, data, operatorData);

    _balances[from] = _balances[from].sub(value);
    _totalSupply = _totalSupply.sub(value);

    emit Burned(operator, from, value, data, operatorData);
  }

  /**
   * [INTERNAL]
   * @dev Check for 'ERC777TokensSender' hook on the sender and call it.
   * May throw according to 'preventLocking'.
   * @param operator Address which triggered the balance decrease (through transfer or burning).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a burn.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information, intended for the token holder ('from').
   * @param operatorData Extra information attached by the operator (if any).
   */
  function _callSender(
    address operator,
    address from,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    internal
  {
    address senderImplementation;
    senderImplementation = interfaceAddr(from, "ERC777TokensSender");

    if (senderImplementation != address(0)) {
      IERC777TokensSender(senderImplementation).tokensToTransfer(operator, from, to, value, data, operatorData);
    }
  }

  /**
   * [INTERNAL]
   * @dev Check for 'ERC777TokensRecipient' hook on the recipient and call it.
   * May throw according to 'preventLocking'.
   * @param operator Address which triggered the balance increase (through transfer or minting).
   * @param from Token holder for a transfer and 0x for a mint.
   * @param to Token recipient.
   * @param value Number of tokens the recipient balance is increased by.
   * @param data Extra information, intended for the token holder ('from').
   * @param operatorData Extra information attached by the operator (if any).
   * @param preventLocking 'true' if you want this function to throw when tokens are sent to a contract not
   * implementing 'ERC777TokensRecipient'.
   * ERC777 native transfer functions MUST set this parameter to 'true', and backwards compatible ERC20 transfer
   * functions SHOULD set this parameter to 'false'.
   */
  function _callRecipient(
    address operator,
    address from,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData,
    bool preventLocking
  )
    internal
  {
    address recipientImplementation;
    recipientImplementation = interfaceAddr(to, "ERC777TokensRecipient");

    if (recipientImplementation != address(0)) {
      IERC777TokensRecipient(recipientImplementation).tokensReceived(operator, from, to, value, data, operatorData);
    } else if (preventLocking) {
      require(_isRegularAddress(to), "A6: Transfer Blocked - Receiver not eligible");
    }
  }

  /**
   * [INTERNAL]
   * @dev Perform the minting of tokens.
   * @param operator Address which triggered the mint.
   * @param to Token recipient.
   * @param value Number of tokens minted.
   * @param data Information attached to the mint, and intended for the recipient (to).
   * @param operatorData Information attached to the mint by the operator (if any).
   */
  function _mint(address operator, address to, uint256 value, bytes data, bytes operatorData) internal {
    require(_isMultiple(value), "A9: Transfer Blocked - Token granularity");
    require(to != address(0), "A6: Transfer Blocked - Receiver not eligible");      // forbid transfer to 0x0 (=burning)

    _totalSupply = _totalSupply.add(value);
    _balances[to] = _balances[to].add(value);

    _callRecipient(operator, address(0), to, value, data, operatorData, true);

    emit Minted(operator, to, value, data, operatorData);
  }

  /********************** ERC777 OPTIONAL FUNCTIONS ***************************/

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Add a controller for the token.
   * @param operator Address to set as a controller.
   */
  function _addController(address operator) internal {
    require(!_isController[operator], "Action Blocked - Already a controller");
    _controllers.push(operator);
    _isController[operator] = true;
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Remove controller of the token.
   * @param operator Address to remove from controllers.
   */
  function _removeController(address operator) internal {
    require(_isController[operator], "Action Blocked - Not a controller");

    for (uint i = 0; i<_controllers.length; i++){
      if(_controllers[i] == operator) {
        _controllers[i] = _controllers[_controllers.length - 1];
        delete _controllers[_controllers.length-1];
        _controllers.length--;
        break;
      }
    }
    _isController[operator] = false;
  }
}
