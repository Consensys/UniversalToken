/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;


import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "contract-certificate-controller/contracts/CertificateController.sol";
import "erc820/contracts/ERC820Client.sol";

import "./IERC777.sol";
import "./IERC777TokensSender.sol";
import "./IERC777TokensRecipient.sol";


contract ERC777 is IERC777, Ownable, ERC820Client, CertificateController {
  using SafeMath for uint256;

  string internal _name;
  string internal _symbol;
  uint256 internal _granularity;
  uint256 internal _totalSupply;

  // Mapping from investor to balance [OVERRIDES ERC20]
  mapping(address => uint256) internal _balances;

  // Mapping from (investor, spender) to allowed amount [NOT MANDATORY FOR ERC777 STANDARD][OVERRIDES ERC20]
  mapping (address => mapping (address => uint256)) internal _allowed;



  /******************** Mappings to find operator *****************************/
  // Mapping from (operator, investor) to authorized status [INVESTOR-SPECIFIC]
  mapping(address => mapping(address => bool)) internal _authorized;

  // Mapping from (operator, investor) to revoked status [INVESTOR-SPECIFIC]
  mapping(address => mapping(address => bool)) internal _revokedDefaultOperator;

  // Array of default operators [NOT INVESTOR-SPECIFIC]
  address[] internal _defaultOperators;

  // Mapping from operator to defaultOperator status [NOT INVESTOR-SPECIFIC]
  mapping(address => bool) internal _isDefaultOperator;
  /****************************************************************************/

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner
  )
    public
    CertificateController(certificateSigner)
  {
    _name = name;
    _symbol = symbol;
    _totalSupply = 0;
    require(granularity >= 1);
    _granularity = granularity;

    for (uint i = 0; i < defaultOperators.length; i++) {
      _addDefaultOperator(defaultOperators[i]);
    }

    setInterfaceImplementation("ERC777Token", this);
  }

  /**
   * [ERC777 INTERFACE (1/13)]
   * @dev Returns the name of the token, e.g., "MyToken".
   * @return Name of the token.
   */
  function name() external view returns(string) {
    return _name;
  }

  /**
   * [ERC777 INTERFACE (2/13)]
   * @dev Returns the symbol of the token, e.g., "MYT".
   * @return Symbol of the token.
   */
  function symbol() external view returns(string) {
    return _symbol;
  }

  /**
   * [ERC777 INTERFACE (3/13)][OVERRIDES ERC20 METHOD] - Required since '_totalSupply' is private in ERC20
   * @dev Get the total number of minted tokens.
   * @return Total supply of tokens currently in circulation.
   */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /**
   * [ERC777 INTERFACE (4/13)] [OVERRIDES ERC20 METHOD] - Required since '_balances' is private in ERC20
   * @dev Get the balance of the account with address tokenHolder.
   * @param tokenHolder Address for which the balance is returned.
   * @return Amount of token held by tokenHolder in the token contract.
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
   * @dev Get the list of default operators as defined by the token contract.
   * @return List of addresses of all the default operators.
   */
  function defaultOperators() external view returns (address[]) {
    return _getDefaultOperators(true);
  }

  /**
   * @dev Get the list of default operators as defined by the token contract.
   * @param isControllable 'true' if token can have default operators, 'false' if not.
   * @return List of addresses of all the default operators.
   */
  function _getDefaultOperators(bool isControllable) internal view returns (address[]) {
    if (isControllable) {
      return _defaultOperators;
    } else {
      return new address[](0);
    }
  }

  /**
   * [ERC777 INTERFACE (7/13)]
   * @dev Set a third party operator address as an operator of msg.sender to send and burn tokens on its
   * behalf.
   * @param operator Address to set as an operator for msg.sender.
   */
  function authorizeOperator(address operator) external {
    _revokedDefaultOperator[operator][msg.sender] = false;
    _authorized[operator][msg.sender] = true;
    emit AuthorizedOperator(operator, msg.sender);
  }

  /**
   * [ERC777 INTERFACE (8/13)]
   * @dev Remove the right of the operator address to be an operator for msg.sender and to send
   * and burn tokens on its behalf.
   * @param operator Address to rescind as an operator for msg.sender.
   */
  function revokeOperator(address operator) external {
    _revokedDefaultOperator[operator][msg.sender] = true;
    _authorized[operator][msg.sender] = false;
    emit RevokedOperator(operator, msg.sender);
  }

  /**
   * [ERC777 INTERFACE (9/13)]
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of tokenHolder.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator.
   * @return true if operator is an operator of tokenHolder and false otherwise.
   */
  function isOperatorFor(address operator, address tokenHolder) external view returns (bool) {
    return _isOperatorFor(operator, tokenHolder, false);
  }

  /**
   * [ERC777 INTERFACE (10/13)]
   * @dev Send the amount of tokens from the address msg.sender to the address to.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
   */
  function sendTo(address to, uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _sendTo(msg.sender, msg.sender, to, amount, data, "", true);
  }

  /**
   * [ERC777 INTERFACE (11/13)]
   * @dev Send the amount of tokens on behalf of the address from to the address to.
   * @param from Token holder (or address(0) to set from to msg.sender).
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from).
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   */
  function operatorSendTo(address from, address to, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from, false));

    _sendTo(msg.sender, _from, to, amount, data, operatorData, true);
  }

  /**
   * [ERC777 INTERFACE (12/13)]
   * @dev Burn the amount of tokens from the address msg.sender.
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, by the token holder [contains the conditional ownership certificate].
   */
  function burn(uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _burn(msg.sender, msg.sender, amount, data, "");
  }

  /**
   * [ERC777 INTERFACE (13/13)]
   * @dev Burn the amount of tokens on behalf of the address from.
   * @param from Token holder whose tokens will be burned (or address(0) to set from to msg.sender).
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, and intended for the token holder (from).
   * @param operatorData Information attached to the burn by the operator [contains the conditional ownership certificate].
   */
  function operatorBurn(address from, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from, false));

    _burn(msg.sender, _from, amount, data, operatorData);
  }

  /**
   * @dev Internal function that checks if `amount` is multiple of the granularity.
   * @param amount The quantity that want's to be checked.
   * @return `true` if `amount` is a multiple of the granularity.
   */
  function _isMultiple(uint256 amount) internal view returns(bool) {
    return(amount.div(_granularity).mul(_granularity) == amount);
  }

  /**
   * @dev Check whether an address is a regular address or not.
   * @param addr Address of the contract that has to be checked.
   * @return `true` if `addr` is a regular address (not a contract).
   */
  function _isRegularAddress(address addr) internal view returns(bool) {
    if (addr == address(0)) { return false; }
    uint size;
    assembly { size := extcodesize(addr) } // solhint-disable-line no-inline-assembly
    return size == 0;
  }

  /**
   * @dev Indicate whether the operator address is an operator of the tokenHolder address.
   * @param operator Address which may be an operator of tokenHolder.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator.
   * @return true if operator is an operator of tokenHolder and false otherwise.
   */
  function _isOperatorFor(address operator, address tokenHolder, bool isControllable) internal view returns (bool) {
    return (operator == tokenHolder
      || _authorized[operator][tokenHolder]
      || (_isDefaultOperator[operator] && !_revokedDefaultOperator[operator][tokenHolder])
      || (_isDefaultOperator[operator] && isControllable)
    );
  }

   /**
    * @dev Helper function actually performing the sending of tokens.
    * @param operator The address performing the send.
    * @param from Token holder.
    * @param to Token recipient.
    * @param amount Number of tokens to send.
    * @param data Information attached to the send, and intended for the token holder (from).
    * @param operatorData Information attached to the send by the operator.
    * @param preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    *  implementing `erc777tokenHolder`.
    *  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    *  functions SHOULD set this parameter to `false`.
    */
  function _sendTo(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData,
    bool preventLocking
  )
    internal
  {
    require(_isMultiple(amount));
    require(to != address(0));          // forbid sending to address(0) (=burning)
    require(_balances[from] >= amount); // ensure enough funds

    _callSender(operator, from, to, amount, data, operatorData);

    _balances[from] = _balances[from].sub(amount);
    _balances[to] = _balances[to].add(amount);

    _callRecipient(operator, from, to, amount, data, operatorData, preventLocking);

    emit Sent(operator, from, to, amount, data, operatorData);
  }

  /**
   * @dev Helper function actually performing the burning of tokens.
   * @param operator The address performing the burn.
   * @param from Token holder whose tokens will be burned.
   * @param amount Number of tokens to burn.
   * @param data Information attached to the burn, and intended for the token holder (from).
   * @param operatorData Information attached to the burn by the operator (if any).
   */
  function _burn(address operator, address from, uint256 amount, bytes data, bytes operatorData)
    internal
  {
    require(_isMultiple(amount));
    require(from != address(0));
    require(_balances[from] >= amount);

    _callSender(operator, from, address(0), amount, data, operatorData);

    _balances[from] = _balances[from].sub(amount);
    _totalSupply = _totalSupply.sub(amount);

    emit Burned(operator, from, amount, data, operatorData);
  }

  /**
   * @dev Helper function that checks for ERC777TokensSender on the sender and calls it.
   *  May throw according to `preventLocking`
   * @param operator Address which triggered the balance decrease (through sending or burning).
   * @param from Token holder.
   * @param to Token recipient for a send and 0x for a burn.
   * @param amount Number of tokens the token holder balance is decreased by.
   * @param data Extra information, intended for the token holder (from).
   * @param operatorData Extra information attached by the operator (if any).
   */
  function _callSender(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
  {
    address senderImplementation;
    senderImplementation = interfaceAddr(from, "ERC777TokensSender");

    if (senderImplementation != address(0)) {
      IERC777TokensSender(senderImplementation).tokensToSend(operator, from, to, amount, data, operatorData);
    }
  }

  /**
   * @dev Helper function that checks for ERC777TokensRecipient on the recipient and calls it.
   *  May throw according to `preventLocking`
   * @param operator Address which triggered the balance increase (through sending or minting).
   * @param from Token holder for a send and 0x for a mint.
   * @param to Token recipient.
   * @param amount Number of tokens the recipient balance is increased by.
   * @param data Extra information, intended for the token holder (from).
   * @param operatorData Extra information attached by the operator (if any).
   * @param preventLocking `true` if you want this function to throw when tokens are sent to a contract not
   *  implementing `ERC777TokensRecipient`.
   *  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
   *  functions SHOULD set this parameter to `false`.
   */
  function _callRecipient(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData,
    bool preventLocking
  )
    internal
  {
    address recipientImplementation;
    recipientImplementation = interfaceAddr(to, "ERC777TokensRecipient");

    if (recipientImplementation != address(0)) {
      IERC777TokensRecipient(recipientImplementation).tokensReceived(operator, from, to, amount, data, operatorData);
    } else if (preventLocking) {
      require(_isRegularAddress(to));
    }
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Internal function to add a default operator for the token.
   * @param operator Address to set as a default operator.
   */
  function _addDefaultOperator(address operator) internal {
    require(!_isDefaultOperator[operator]);
    _defaultOperators.push(operator);
    _isDefaultOperator[operator] = true;
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD][SHALL BE CALLED ONLY FROM ERC1400]
   * @dev Internal function to add a default operator for the token.
   * @param operator Address to set as a default operator.
   */
  function _removeDefaultOperator(address operator) internal {
    require(_isDefaultOperator[operator]);

    for (uint i = 0; i<_defaultOperators.length; i++){
      if(_defaultOperators[i] == operator) {
        _defaultOperators[i] = _defaultOperators[_defaultOperators.length - 1];
        delete _defaultOperators[_defaultOperators.length-1];
        _defaultOperators.length--;
        break;
      }
    }
    _isDefaultOperator[operator] = false;
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD]
   * @dev Helper function actually performing the minting of tokens.
   * @param operator Address which triggered the mint.
   * @param to Token recipient.
   * @param amount Number of tokens minted.
   * @param data Information attached to the mint, and intended for the recipient (to).
   * @param operatorData Information attached to the mint by the operator (if any).
   */
  function _mint(address operator, address to, uint256 amount, bytes data, bytes operatorData)
  internal
  {
    require(_isMultiple(amount));
    require(to != address(0));      // forbid sending to 0x0 (=burning)

    _totalSupply = _totalSupply.add(amount);
    _balances[to] = _balances[to].add(amount);

    _callRecipient(operator, address(0), to, amount, data, operatorData, true);

    emit Minted(operator, to, amount, data, operatorData);
  }


}
