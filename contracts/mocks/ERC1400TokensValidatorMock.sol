pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../token/ERC1400Raw/IERC1400TokensValidator.sol";
import "erc1820/contracts/ERC1820Client.sol";
import "../token/ERC1820/ERC1820Implementer.sol";

import "../IERC1400.sol";
import "../token/ERC1400Partition/IERC1400Partition.sol";
import "../token/ERC1400Raw/IERC1400Raw.sol";
import "../token/ERC1400Raw/IERC1400TokensSender.sol";
import "../token/ERC1400Raw/IERC1400TokensRecipient.sol";


contract ERC1400TokensValidatorMock is IERC1400TokensValidator, WhitelistedRole, ERC1820Client, ERC1820Implementer {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

  bytes4 constant internal ERC20_TRANSFER_FUNCTION_ID = bytes4(keccak256("transfer(address,uint256)"));
  bytes4 constant internal ERC20_TRANSFERFROM_FUNCTION_ID = bytes4(keccak256("transferFrom(address,address,uint256)"));

  // bytes4 constant internal ERC1400Raw_ISSUE_ID = bytes4(keccak256("issue(address,uint256,bytes)"));
  // bytes4 constant internal ERC1400Raw_REDEEM_ID = bytes4(keccak256("redeem(uint256,bytes)"));
  // bytes4 constant internal ERC1400Raw_REDEEM_FROM_ID = bytes4(keccak256("redeemFrom(address,uint256,bytes,bytes)"));

  // bytes4 constant internal ERC1400Raw_TRANSFER_WITH_DATA_ID = bytes4(keccak256("transferWithData(address,uint256,bytes)"));
  // bytes4 constant internal ERC1400Raw_TRANSFER_FROM_WITH_DATA_ID = bytes4(keccak256("transferFromWithData(address,address,uint256,bytes,bytes)"));

  // bytes4 constant internal ERC1400_ISSUE_BY_PARTITION_ID = bytes4(keccak256("issueByPartition(bytes32,address,uint256,bytes)"));
  // bytes4 constant internal ERC1400_REDEEM_BY_PARTITION_ID = bytes4(keccak256("redeemByPartition(bytes32,uint256,bytes)"));
  // bytes4 constant internal ERC1400_OPERATOR_REDEEM_BY_PARTITION_ID = bytes4(keccak256("operatorRedeemByPartition(bytes32,address,uint256,bytes,bytes)"));

  // bytes4 constant internal ERC1400_TRANSFER_BY_PARTITION_ID = bytes4(keccak256("transferByPartition(bytes32,address,uint256,bytes)"));
  // bytes4 constant internal ERC1400_OPERATOR_TRANSFER_BY_PARTITION_ID = bytes4(keccak256("operatorTransferByPartition(bytes32,address,address,uint256,bytes,bytes)"));

  constructor() public {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_VALIDATOR);
  }

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

    if(_validationIsRequired(functionID)) {
      if(isWhitelisted(from) && isWhitelisted(to)) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
    
  }

  function _validationIsRequired(bytes4 functionID) internal pure returns(bool) {

    if(areEqual(functionID, ERC20_TRANSFER_FUNCTION_ID) || areEqual(functionID, ERC20_TRANSFERFROM_FUNCTION_ID)) {
      return true;
    } else {
      return false;
    }
  }

  function areEqual(bytes4 a, bytes4 b) internal pure returns(bool) {
    for (uint256 i = 0; i < a.length; i++) {
      if(a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

}