/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./ERC777.sol";


contract ERC777ERC20 is Ownable, MinterRole, IERC20, ERC777 {

  using SafeMath for uint256;

  bool internal _erc20compatible;

  mapping (address => mapping (address => uint256)) private _allowed;

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators
    )
    public
    ERC777(name, symbol, granularity, defaultOperators)
    {
      _setERC20compatibility(true);
    }

    /**
    *  @dev Registers/Unregisters the ERC20Token interface with its own address via ERC820
    *  @param erc20compatible 'true' to register the ERC20Token interface, 'false' to unregister
    */
    function setERC20compatibility(bool erc20compatible) external onlyOwner {
      _setERC20compatibility(erc20compatible);
    }

    /**
    *  @dev Helper function to registers/unregister the ERC20Token interface
    *  @param erc20compatible 'true' to register the ERC20Token interface, 'false' to unregister
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
      *  @dev Returns the number of decimals of the token.
      *  @return The number of decimals of the token. For Backwards compatibility, decimals are forced to 18 in ERC777.
      */
      function decimals() external pure returns(uint8) {
        return uint8(18);
      }


      /**
      *  @dev Mint the amout of tokens for the recipient 'to'.
      *  @param operator Address which triggered the mint.
      *  @param to Token recipient.
      *  @param amount Number of tokens minted.
      *  @param data Information attached to the minting, and intended for the recipient (to).
      *  @param operatorData Information attached to the minting by the operator.
      */
      function operatorMint(address operator, address to, uint256 amount, bytes data, bytes operatorData)
        external
        onlyMinter
      returns (bool)
      {
        _mint(operator, to, amount, data, operatorData);

        if(_erc20compatible) {
          emit Transfer(address(0), to, amount);  //  ERC20 backwards compatibility
        }

        return true;
      }

      /**
      *  @dev Burn the amount of tokens from the address msg.sender.
      *  @param amount Number of tokens to burn.
      */
      function burn(uint256 amount) public {
        ERC777.burn(amount);

        if(_erc20compatible) {
          emit Transfer(msg.sender, address(0), amount);  //  ERC20 backwards compatibility
        }
      }

      /**
      *  @dev Burn the amount of tokens on behalf of the address from.
      *  @param from Token holder whose tokens will be burned (or 0x0 to set from to msg.sender).
      *  @param amount Number of tokens to burn.
      *  @param operatorData Information attached to the burn by the operator.
      */
      function operatorBurn(address from, uint256 amount, bytes operatorData) public {
        ERC777.operatorBurn(from, amount, operatorData);

        if(_erc20compatible) {
          emit Transfer(from, address(0), amount);  //  ERC20 backwards compatibility
        }
      }

      /**
      * @dev Transfer token for a specified address
      * @param to The address to transfer to.
      * @param value The amount to be transferred.
      */
      function transfer(address to, uint256 value) public returns (bool) {
        require(_erc20compatible);

        _callSender(msg.sender, msg.sender, to, value, "", "");
        _transfer(msg.sender, to, value);
        _callRecipient(msg.sender, msg.sender, to, value, "", "", false);

        emit Sent(msg.sender, msg.sender, to, value, "", "");
        return true;
      }

      /**
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
        public
        returns (bool)
        {
          require(_erc20compatible);
          require(value <= _allowed[from][msg.sender]);

          _callSender(msg.sender, from, to, value, "", "");
          _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
          _transfer(from, to, value);
          _callRecipient(msg.sender, from, to, value, "", "", false);

          emit Sent(msg.sender, from, to, value, "", "");
          return true;
        }

        /**
        *  @dev Helper function actually performing the minting of tokens.
        *  @param operator Address which triggered the mint.
        *  @param to Token recipient.
        *  @param amount Number of tokens minted.
        *  @param data Information attached to the minting, and intended for the recipient (to).
        *  @param operatorData Information attached to the minting by the operator.
        */
        function _mint(address operator, address to, uint256 amount, bytes data, bytes operatorData)
        internal
        {
          require(_isMultiple(amount));
          require(to != address(0));          // forbid sending to 0x0 (=burning)

          _totalSupply = _totalSupply.add(amount);
          _balances[to] = _balances[to].add(amount);

          _callRecipient(operator, address(0), to, amount, data, operatorData, true);

          emit Minted(operator, to, amount, data, operatorData);
        }


  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(
    address owner,
    address spender
   )
    public
    view
    returns (uint256)
  {
    return _allowed[owner][spender];
  }

    /**
  * @dev Transfer token for a specified addresses
  * @param from The address to transfer from.
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function _transfer(address from, address to, uint256 value) internal {
    require(value <= _balances[from]);
    require(to != address(0));

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value) public returns (bool) {
    require(spender != address(0));

    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

}