/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../ERC1400.sol";


contract ERC1400ERC20 is IERC20, ERC1400 {

  bool internal _erc20compatible;

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner
  )
    public
    ERC1400(name, symbol, granularity, defaultOperators, certificateSigner)
  {
    _setERC20compatibility(true);
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD]
   * @dev Registers/Unregisters the ERC20Token interface with its own address via ERC820
   * @param erc20compatible 'true' to register the ERC20Token interface, 'false' to unregister
   */
  function setERC20compatibility(bool erc20compatible) external onlyOwner {
    _setERC20compatibility(erc20compatible);
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD]
   * @dev Helper function to registers/unregister the ERC20Token interface
   * @param erc20compatible 'true' to register the ERC20Token interface, 'false' to unregister
   */
  function _setERC20compatibility(bool erc20compatible) internal {
    _erc20compatible = erc20compatible;
    if(_erc20compatible) {
      setInterfaceImplementation("ERC20Token", this);
    } else {
      setInterfaceImplementation("ERC20Token", address(0));
    }
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
   ERC777._sendTo(operator, from, to, amount, data, operatorData, preventLocking);

   if(_erc20compatible) {
     emit Transfer(from, to, amount);
   }
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
   ERC777._burn(operator, from, amount, data, operatorData);

   if(_erc20compatible) {
     emit Transfer(from, address(0), amount);  //  ERC20 backwards compatibility
   }
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
   ERC777._mint(operator, to, amount, data, operatorData);

   if(_erc20compatible) {
     emit Transfer(address(0), to, amount);  //  ERC20 backwards compatibility
   }
 }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD]
   * @dev Returns the number of decimals of the token.
   * @return The number of decimals of the token. For Backwards compatibility, decimals are forced to 18 in ERC777.
   */
  function decimals() external view returns(uint8) {
    require(_erc20compatible, "Action Blocked - Token restriction");
    return uint8(18);
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD][OVERRIDES ERC20 METHOD]
   * @dev ERC20 function to check the amount of tokens that an owner allowed to a spender.
   * @param owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(
    address owner,
    address spender
  )
  external
  view
  returns (uint256)
  {
    require(_erc20compatible, "Action Blocked - Token restriction");

    return _allowed[owner][spender];
  }

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD][OVERRIDES ERC20 METHOD]
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   * @return A boolean that indicates if the operation was successful.
   */
  function approve(address spender, uint256 value) external returns (bool) {
    require(_erc20compatible, "A8: Transfer Blocked - Token restriction");

    require(spender != address(0), "A5: Transfer Blocked - Sender not eligible");
    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Transfer token for a specified address
   * @param to The address to transfer to.
   * @param value The amount to be transferred.
   */
  function transfer(address to, uint256 value) external returns (bool) {
    require(_erc20compatible, "A8: Transfer Blocked - Token restriction");

    _sendByDefaultTranches(msg.sender, msg.sender, to, value, "", "");

    return true;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Transfer tokens from one address to another
   * @param from The address which you want to send tokens from
   * @param to The address which you want to transfer to
   * @param value The amount of tokens to be transferred
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  )
    external
    returns (bool)
  {
    require(_erc20compatible, "A8: Transfer Blocked - Token restriction");

    address _from = (from == address(0)) ? msg.sender : from;
    require( _isOperatorFor(msg.sender, _from, _isControllable)
      || (value <= _allowed[_from][msg.sender]), "A7: Transfer Blocked - Identity restriction");

    if(_allowed[_from][msg.sender] >= value) {
      _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(value);
    } else {
      _allowed[_from][msg.sender] = 0;
    }

    _sendByDefaultTranches(msg.sender, _from, to, value, "", "");
    return true;
  }

}
