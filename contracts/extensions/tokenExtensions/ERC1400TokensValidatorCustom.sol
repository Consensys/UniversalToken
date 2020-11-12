/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./roles/LimiterRole.sol";

import "erc1820/contracts/ERC1820Client.sol";
import "../../interface/ERC1820Implementer.sol";

import "../../IERC1400.sol";

import "./IERC1400TokensValidator.sol";

contract ERC1400TokensValidatorCustom is IERC1400TokensValidator, LimiterRole, ERC1820Client, ERC1820Implementer {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  // Mapping from token to limiter activation status.
  mapping(address => bool) internal _limiterActivated;

  // Mapping from token to limit.
  mapping(address => uint256) internal _limit;

  /**
   * @dev Modifier to verify if sender is a pauser.
   */
  modifier onlyLimiter(address token) {
    require(
      msg.sender == token ||
      msg.sender == Ownable(token).owner() ||
      isLimiter(token, msg.sender),
      "Sender is not a limiter"
    );
    _;
  }

  /*
   * ================================== GENERIC SETUP ==================================
   * The purpose of this "custom" extension is to enable developers to create
   * their own transfer validation rules (adapted to their use case).
   * By default the token smart contract is linked to the "generic" extension:
   *      ___________         _______________________
   *      |  TOKEN  |   -->   | "Generic" EXTENSION |
   *      -----------         -----------------------
   *
   *
   * ================================== CUSTOM SETUP #1 ==================================
   * In order to replace the "generic" extension by a "custom" extension:
   *  1) Deploy this smart contract with "_nextExtension" parameter set to address(0) in the constructor
   *  2) Once deployed, retrieve address of this deployed contract
   *  3) Call the token smart contract's "setTokenExtension" function by indicating this new address as parameter 
   * This will replace the "generic" extension by the "custom" extension:
   *      ___________         _______________________
   *      |  TOKEN  |   -->   | "Custom" EXTENSION  | 
   *      -----------         -----------------------
   *
   *
   * ================================== CUSTOM SETUP #2 ==================================
   * In order to add a "custom" extension on top of the "generic" extension:
   *  1) Deploy this smart contract with "_nextExtension" parameter set to the "generic" extension's address in the constructor
   *  2) Once deployed, retrieve address of this deployed contract
   *  3) Call the token smart contract's "setTokenExtension" function by indicating this new address as parameter 
   * This will add the "custom" extension on top of the "generic" extension:
   *      ___________         _______________________         _______________________
   *      |  TOKEN  |   -->   | "Custom" EXTENSION  |   -->   | "Generic" EXTENSION | 
   *      -----------         -----------------------         -----------------------
   *
   */

  constructor(address _nextExtension) public {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_VALIDATOR);
    
    if(_nextExtension != address(0)) {
      // Indicate the address of the next extension (only for CUSTOM SETUP #2)
      _setTokenExtension(_nextExtension, ERC1400_TOKENS_VALIDATOR);
    }
  }

  /**
   * @dev Get the list of token controllers for a given token.
   * @return Setup of a given token.
   */
  function retrieveTokenSetup(address token) external view returns (bool) {
    return (
      _limiterActivated[token]
    );
  }

  /**
   * @dev Register token setup.
   */
  function registerTokenSetup(
    address token,
    bool limiterActivated
  ) external onlyLimiter(token) {
    _limiterActivated[token] = limiterActivated;
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @param token Token address.
   * @param payload Payload of the initial transaction.
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
    view 
    returns(bool)
  {
    address nextExtension = interfaceAddr(address(this), ERC1400_TOKENS_VALIDATOR);
    if((nextExtension != address(0))
      && !IERC1400TokensValidator(nextExtension).canValidate(token, payload, partition, operator, from, to, value, data, operatorData))
      return false;

    if(!_canValidateLimitedToken(token, value)) {
      return false;
    }

    return true;
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
   * @return 'true' if the token transfer can be validated, 'false' if not.
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
  {
    address nextExtension = interfaceAddr(address(this), ERC1400_TOKENS_VALIDATOR);
    if(nextExtension != address(0)) {
      (bool success,) = nextExtension.call(abi.encodeWithSignature("tokensToValidate(bytes,bytes32,address,address,address,uint256,bytes,bytes calldata operatorData)", payload, partition, operator, from, to, value, data, operatorData));
      require(success);
    }

    require(_canValidateLimitedToken(msg.sender, value), "50"); // 0x50	transfer failure
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   * @return hold ID in case a hold can be executed for the given parameters.
   */
  function _canValidateLimitedToken(
    address token,
    uint256 value
  )
    internal
    view
    returns(bool)
  {
    if(_limit[token] != 0 && value > _limit[token]) {
      return false;
    } else {
      return true;
    }
  }

  /************************************** Token extension *****************************************/
  /**
   * @dev Set token extension contract address.
   * The extension contract can for example verify "ERC1400TokensValidator" or "ERC1400TokensChecker" interfaces.
   * If the extension is an "ERC1400TokensValidator", it will be called everytime a transfer is executed.
   * @param extension Address of the extension contract.
   * @param interfaceLabel Interface label of extension contract.
   */
  function _setTokenExtension(address extension, string memory interfaceLabel) internal {
    ERC1820Client.setInterfaceImplementation(interfaceLabel, extension);
  }
  /************************************************************************************************/

}