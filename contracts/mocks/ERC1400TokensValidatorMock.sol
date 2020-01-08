pragma solidity ^0.5.0;

import "../token/ERC1400Raw/IERC1400TokensValidator.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./roles/BlacklistedRole.sol";

import "erc1820/contracts/ERC1820Client.sol";
import "../token/ERC1820/ERC1820Implementer.sol";

import "../IERC1400.sol";
import "../token/ERC1400Partition/IERC1400Partition.sol";
import "../token/ERC1400Raw/IERC1400Raw.sol";
import "../token/ERC1400Raw/IERC1400TokensSender.sol";
import "../token/ERC1400Raw/IERC1400TokensRecipient.sol";


contract ERC1400TokensValidatorMock is IERC1400TokensValidator, Ownable, Pausable, WhitelistedRole, BlacklistedRole, ERC1820Client, ERC1820Implementer {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  bytes4 constant internal ERC20_TRANSFER_FUNCTION_ID = bytes4(keccak256("transfer(address,uint256)"));
  bytes4 constant internal ERC20_TRANSFERFROM_FUNCTION_ID = bytes4(keccak256("transferFrom(address,address,uint256)"));

  bool internal _whitelistActivated;
  bool internal _blacklistActivated;

  constructor(bool whitelistActivated, bool blacklistActivated) public {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_VALIDATOR);

    _whitelistActivated = whitelistActivated;
    _blacklistActivated = blacklistActivated;
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @param functionID ID of the function that is called.
   * @param partition Name of the partition (left empty for ERC1400Raw transfer).
   * @param operator Address which triggered the balance decrease (through transfer or redemption).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a redemption.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information.
   * @param operatorData Extra information, attached by the operator (if any).
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function canValidate(
    bytes4 functionID,
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
    return(_canValidate(functionID, partition, operator, from, to, value, data, operatorData));
  }

  /**
   * @dev Function called by the token contract before executing a transfer.
   * @param functionID ID of the function that is called.
   * @param partition Name of the partition (left empty for ERC1400Raw transfer).
   * @param operator Address which triggered the balance decrease (through transfer or redemption).
   * @param from Token holder.
   * @param to Token recipient for a transfer and 0x for a redemption.
   * @param value Number of tokens the token holder balance is decreased by.
   * @param data Extra information.
   * @param operatorData Extra information, attached by the operator (if any).
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function tokensToValidate(
    bytes4 functionID,
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
    require(_canValidate(functionID, partition, operator, from, to, value, data, operatorData), "A7"); // Transfer Blocked - Identity restriction
  }

  /**
   * @dev Verify if a token transfer can be executed or not, on the validator's perspective.
   * @return 'true' if the token transfer can be validated, 'false' if not.
   */
  function _canValidate(
    bytes4 functionID,
    bytes32 /*partition*/,
    address /*operator*/,
    address from,
    address to,
    uint /*value*/,
    bytes memory data,
    bytes memory /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    view
    whenNotPaused
    returns(bool)
  {

    bytes32 transferRevert = 0x3300000000000000000000000000000000000000000000000000000000000000; // Default sender hook failure data for the mock only
    bytes32 data32;
    assembly {
        data32 := mload(add(data, 32))
    }
    if (data32 == transferRevert) {
      return false;
    }

    if(_functionRequiresValidation(functionID)) {
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
    
    return true;
  }

  /**
   * @dev Check if validator is activated for the function called in the smart contract.
   * @param functionID ID of the function that is called.
   * @return 'true' if the function requires validation, 'false' if not.
   */
  function _functionRequiresValidation(bytes4 functionID) internal pure returns(bool) {

    if(areEqual(functionID, ERC20_TRANSFER_FUNCTION_ID) || areEqual(functionID, ERC20_TRANSFERFROM_FUNCTION_ID)) {
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

}