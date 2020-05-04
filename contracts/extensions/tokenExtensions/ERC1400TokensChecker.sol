/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "erc1820/contracts/ERC1820Client.sol";
import "../../interface/ERC1820Implementer.sol";

import "../../ERC1400.sol";

import "../userExtensions/IERC1400TokensSender.sol";
import "../userExtensions/IERC1400TokensRecipient.sol";

import "./IERC1400TokensValidator.sol";
import "./IERC1400TokensChecker.sol";

contract ERC1400TokensChecker is IERC1400TokensChecker, ERC1820Client, ERC1820Implementer {
  using SafeMath for uint256;

  string constant internal ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";
  string constant internal ERC1400_TOKENS_CHECKER = "ERC1400TokensChecker";

  string constant internal ERC1400_TOKENS_SENDER = "ERC1400TokensSender";
  string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

  constructor() public {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_CHECKER);
  }

  /**
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param functionSig ID of the function that needs to be called.
   * @param partition Name of the partition.
   * @param operator The address performing the transfer.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
   * @param operatorData Information attached to the transfer, by the operator (if any).
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   * @return Destination partition.
   */
   function canTransferByPartition(bytes4 functionSig, bytes32 partition, address operator, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData)
     external
     view
     returns (byte, bytes32, bytes32)
   {
     return _canTransferByPartition(functionSig, partition, operator, from, to, value, data, operatorData);
   }

  /**
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param functionSig ID of the function that needs to be called.
   * @param partition Name of the partition.
   * @param operator The address performing the transfer.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
   * @param operatorData Information attached to the transfer, by the operator (if any).
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   * @return Destination partition.
   */
   function _canTransferByPartition(bytes4 functionSig, bytes32 partition, address operator, address from, address to, uint256 value, bytes memory data, bytes memory operatorData)
     internal
     view
     returns (byte, bytes32, bytes32)
   {
     if(!ERC1400(msg.sender).isOperatorForPartition(partition, operator, from))
       return(hex"58", "", partition); // 0x58	invalid operator (transfer agent)

     if((IERC20(msg.sender).balanceOf(from) < value) || (ERC1400(msg.sender).balanceOfByPartition(partition, from) < value))
       return(hex"52", "", partition); // 0x52	insufficient balance

     if(to == address(0))
       return(hex"57", "", partition); // 0x57	invalid receiver

     address hookImplementation;
     
     hookImplementation = ERC1820Client.interfaceAddr(from, ERC1400_TOKENS_SENDER);
     if((hookImplementation != address(0))
       && !IERC1400TokensSender(hookImplementation).canTransfer(functionSig, partition, operator, from, to, value, data, operatorData))
       return(hex"56", "", partition); // 0x56	invalid sender

     hookImplementation = ERC1820Client.interfaceAddr(to, ERC1400_TOKENS_RECIPIENT);
     if((hookImplementation != address(0))
       && !IERC1400TokensRecipient(hookImplementation).canReceive(functionSig, partition, operator, from, to, value, data, operatorData))
       return(hex"57", "", partition); // 0x57	invalid receiver

     hookImplementation = ERC1820Client.interfaceAddr(msg.sender, ERC1400_TOKENS_VALIDATOR);
     if((hookImplementation != address(0))
       && !IERC1400TokensValidator(hookImplementation).canValidate(functionSig, partition, operator, from, to, value, data, operatorData))
       return(hex"54", "", partition); // 0x54	transfers halted (contract paused)

     uint256 granularity = ERC1400(msg.sender).granularity();
     if(!(value.div(granularity).mul(granularity) == value))
       return(hex"50", "", partition); // 0x50	transfer failure

     return(hex"51", "", partition);  // 0x51	transfer success
   }

  /**
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   */
  // function canTransfer(bytes4 /*functionSig*/, address /*operator*/, address /*from*/, address /*to*/, uint256 /*value*/, bytes calldata /*data*/, bytes calldata /*operatorData*/)
  //   external
  //   view
  //   returns (byte, bytes32)
  // {
  //   if(!ERC1400(msg.sender).isOperator(operator, from))
  //      return(hex"58", ""); // 0x58	invalid operator (transfer agent)

  //   byte esc;

  //   bytes32[] memory defaultPartitions = ERC1400(msg.sender).getDefaultPartitions();

  //   if(defaultPartitions.length == 0) {
  //     return(hex"55", ""); // 0x55	funds locked (lockup period)
  //   }

  //   uint256 _remainingValue = value;
  //   uint256 _localBalance;

  //   for (uint i = 0; i < defaultPartitions.length; i++) {
  //     _localBalance = ERC1400(msg.sender).balanceOfByPartition(defaultPartitions[i], from);
  //     if(_remainingValue <= _localBalance) {
  //       (esc,,) = _canTransferByPartition(functionSig, defaultPartitions[i], operator, from, to, _remainingValue, data, operatorData);
  //       _remainingValue = 0;
  //       break;
  //     } else if (_localBalance != 0) {
  //       (esc,,) = _canTransferByPartition(functionSig, defaultPartitions[i], operator, from, to, _localBalance, data, operatorData);
  //       _remainingValue = _remainingValue - _localBalance;
  //     }
  //     if(esc != hex"51") {
  //       return(esc, "");
  //     }
  //   }

  //   if(_remainingValue != 0) {
  //     return(hex"52", ""); // 0x52	insufficient balance
  //   }

  //   return(hex"51", ""); // 0x51	transfer success

  //   return(hex"00", "");
  // }

}