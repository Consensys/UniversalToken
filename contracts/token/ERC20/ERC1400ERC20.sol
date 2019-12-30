/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../../ERC1400.sol";


/**
 * @title ERC1400ERC20
 * @dev ERC1400 with ERC20 retrocompatibility
 */
contract ERC1400ERC20 is IERC20, ERC1400 {

  string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
  bytes32 internal _interfaceHash20;

  // Mapping from (tokenHolder, spender) to allowed value.
  mapping (address => mapping (address => uint256)) internal _allowed;

  // Mapping from (tokenHolder) to whitelisted status.
  mapping (address => bool) internal _whitelisted;

  /**
   * @dev Modifier to verify if sender and recipient are whitelisted.
   */
  modifier areWhitelisted(address sender, address recipient) {
    require(_whitelisted[sender], "A5"); // Transfer Blocked - Sender not eligible
    require(_whitelisted[recipient], "A6"); // Transfer Blocked - Receiver not eligible
    _;
  }

  /**
   * [ERC1400ERC20 CONSTRUCTOR]
   * @dev Initialize ERC71400ERC20 and CertificateController parameters + register
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
    address certificateSigner,
    bytes32[] memory tokenDefaultPartitions
  )
    public
    ERC1400(name, symbol, granularity, controllers, certificateSigner, tokenDefaultPartitions)
  {
    ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, address(this));

    _interfaceHash20 = keccak256(abi.encodePacked(ERC20_INTERFACE_NAME)); // For migration
  }

  /**
   * [OVERRIDES ERC1400 METHOD]
   * @dev Perform the transfer of tokens.
   * @param operator The address performing the transfer.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer.
   * @param operatorData Information attached to the transfer by the operator (if any).
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
  {
    ERC1400Raw._transferWithData(operator, from, to, value, data, operatorData);

    emit Transfer(from, to, value);
  }

  /**
   * [OVERRIDES ERC1400 METHOD]
   * @dev Perform the token redemption.
   * @param operator The address performing the redemption.
   * @param from Token holder whose tokens will be redeemed.
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption by the operator (if any).
   */
  function _redeem(address operator, address from, uint256 value, bytes memory data, bytes memory operatorData) internal {
    ERC1400Raw._redeem(operator, from, value, data, operatorData);

    emit Transfer(from, address(0), value);  //  ERC20 backwards compatibility
  }

  /**
   * [OVERRIDES ERC1400 METHOD]
   * @dev Perform the issuance of tokens.
   * @param operator Address which triggered the issuance.
   * @param to Token recipient.
   * @param value Number of tokens issued.
   * @param data Information attached to the issuance.
   * @param operatorData Information attached to the issuance by the operator (if any).
   */
  function _issue(address operator, address to, uint256 value, bytes memory data, bytes memory operatorData) internal {
    ERC1400Raw._issue(operator, to, value, data, operatorData);

    emit Transfer(address(0), to, value); // ERC20 backwards compatibility
  }

  /**
   * [OVERRIDES ERC1400 METHOD]
   * @dev Get the number of decimals of the token.
   * @return The number of decimals of the token. For Backwards compatibility, decimals are forced to 18 in ERC1400Raw.
   */
  function decimals() external pure returns(uint8) {
    return uint8(18);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Check the value of tokens that an owner allowed to a spender.
   * @param owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the value of tokens still available for the spender.
   */
  function allowance(address owner, address spender) external view returns (uint256) {
    return _allowed[owner][spender];
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of 'msg.sender'.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   * @return A boolean that indicates if the operation was successful.
   */
  function approve(address spender, uint256 value) external returns (bool) {
    require(spender != address(0), "A5"); // Transfer Blocked - Sender not eligible
    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Transfer token for a specified address.
   * @param to The address to transfer to.
   * @param value The value to be transferred.
   * @return A boolean that indicates if the operation was successful.
   */
  function transfer(address to, uint256 value) external areWhitelisted(msg.sender, to) returns (bool) {
    _transferByDefaultPartitions(msg.sender, msg.sender, to, value, "", "", false);
    return true;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Transfer tokens from one address to another.
   * @param from The address which you want to transfer tokens from.
   * @param to The address which you want to transfer to.
   * @param value The amount of tokens to be transferred.
   * @return A boolean that indicates if the operation was successful.
   */
  function transferFrom(address from, address to, uint256 value) external areWhitelisted(from, to) returns (bool) {
    require( _isOperator(msg.sender, from)
      || (value <= _allowed[from][msg.sender]), "A7"); // Transfer Blocked - Identity restriction

    if(_allowed[from][msg.sender] >= value) {
      _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
    } else {
      _allowed[from][msg.sender] = 0;
    }

    _transferByDefaultPartitions(msg.sender, from, to, value, "", "", false);
    return true;
  }

  /***************** ERC1400ERC20 OPTIONAL FUNCTIONS ***************************/

  /**
   * [NOT MANDATORY FOR ERC1400ERC20 STANDARD]
   * @dev Get whitelisted status for a tokenHolder.
   * @param tokenHolder Address whom to check the whitelisted status for.
   * @return bool 'true' if tokenHolder is whitelisted, 'false' if not.
   */
  function whitelisted(address tokenHolder) external view returns (bool) {
    return _whitelisted[tokenHolder];
  }

  /**
   * [NOT MANDATORY FOR ERC1400ERC20 STANDARD]
   * @dev Set whitelisted status for a tokenHolder.
   * @param tokenHolder Address to add/remove from whitelist.
   * @param authorized 'true' if tokenHolder shall be added to whitelist, 'false' if not.
   */
  function setWhitelisted(address tokenHolder, bool authorized) external {
    require(_isController[msg.sender]);
    _setWhitelisted(tokenHolder, authorized);
  }

  /**
   * [NOT MANDATORY FOR ERC1400ERC20 STANDARD]
   * @dev Set whitelisted status for a tokenHolder.
   * @param tokenHolder Address to add/remove from whitelist.
   * @param authorized 'true' if tokenHolder shall be added to whitelist, 'false' if not.
   */
  function _setWhitelisted(address tokenHolder, bool authorized) internal {
    require(tokenHolder != address(0)); // Action Blocked - Not a valid address
    _whitelisted[tokenHolder] = authorized;
  }

  /************************** REQUIRED FOR MIGRATION FEATURE *******************************/

  /**
   * [ERC1820Implementer INTERFACE (1/1)] [OVERRIDES ERC1400 METHOD]
   * @dev Indicates whether the contract implements the interface `interfaceHash` for the address `addr`.
   * @param interfaceHash keccak256 hash of the name of the interface
   * @return ERC1820_ACCEPT_MAGIC only if the contract implements `ìnterfaceHash` for the address `addr`.
   */
  function canImplementInterfaceForAddress(bytes32 interfaceHash, address /*addr*/) // Comments to avoid compilation warnings for unused variables.
    external
    view
    returns(bytes32)
  {
    if(interfaceHash == _interfaceHash1400 || interfaceHash == _interfaceHash20) {
      return ERC1820_ACCEPT_MAGIC;
    } else {
      return "";
    }
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC1400 METHOD]
   * @dev Migrate contract.
   *
   * ===> CAUTION: DEFINITIVE ACTION
   * 
   * This function shall be called once a new version of the smart contract has been created.
   * Once this function is called:
   *  - The address of the new smart contract is set in ERC1820 registry
   *  - If the choice is definitive, the current smart contract is turned off and can never be used again
   *
   * @param newContractAddress Address of the new version of the smart contract.
   * @param definitive If set to 'true' the contract is turned off definitely.
   */
  function migrate(address newContractAddress, bool definitive) external onlyOwner {
    ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, newContractAddress);
    ERC1400._migrate(newContractAddress, definitive);
  }

}