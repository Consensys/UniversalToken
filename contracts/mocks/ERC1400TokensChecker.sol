pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../token/ERC1400Raw/IERC1400TokensChecker.sol";
import "erc1820/contracts/ERC1820Client.sol";
import "../token/ERC1820/ERC1820Implementer.sol";

import "../IERC1400.sol";
import "../token/ERC1400Partition/IERC1400Partition.sol";
import "../token/ERC1400Raw/IERC1400Raw.sol";
import "../token/ERC1400Raw/IERC1400TokensSender.sol";
import "../token/ERC1400Raw/IERC1400TokensRecipient.sol";
import "../token/ERC1400Raw/IERC1400TokensValidator.sol";


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
   * @param functionID ID of the function that needs to be called.
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
   function canTransferByPartition(bytes4 functionID, bytes32 partition, address operator, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData)
     external
     view
     returns (byte, bytes32, bytes32)
   {
     return _canTransferByPartition(functionID, partition, operator, from, to, value, data, operatorData);
   }

  /**
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param functionID ID of the function that needs to be called.
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
   function _canTransferByPartition(bytes4 functionID, bytes32 partition, address operator, address from, address to, uint256 value, bytes memory data, bytes memory operatorData)
     internal
     view
     returns (byte, bytes32, bytes32)
   {
     if(!IERC1400Partition(msg.sender).isOperatorForPartition(partition, operator, from))
       return(hex"A7", "", partition); // Transfer Blocked - Identity restriction

     if((IERC1400Raw(msg.sender).balanceOf(from) < value) || (IERC1400Partition(msg.sender).balanceOfByPartition(partition, from) < value))
       return(hex"A4", "", partition); // Transfer Blocked - Sender balance insufficient

     if(to == address(0))
       return(hex"A6", "", partition); // Transfer Blocked - Receiver not eligible

     address hookImplementation;
     
     hookImplementation = ERC1820Client.interfaceAddr(from, ERC1400_TOKENS_SENDER);
     if((hookImplementation != address(0))
       && !IERC1400TokensSender(hookImplementation).canTransfer(functionID, partition, operator, from, to, value, data, operatorData))
       return(hex"A5", "", partition); // Transfer Blocked - Sender not eligible

     hookImplementation = ERC1820Client.interfaceAddr(to, ERC1400_TOKENS_RECIPIENT);
     if((hookImplementation != address(0))
       && !IERC1400TokensRecipient(hookImplementation).canReceive(functionID, partition, operator, from, to, value, data, operatorData))
       return(hex"A6", "", partition); // Transfer Blocked - Receiver not eligible

     hookImplementation = ERC1820Client.interfaceAddr(msg.sender, ERC1400_TOKENS_VALIDATOR);
     if((hookImplementation != address(0))
       && !IERC1400TokensValidator(hookImplementation).canValidate(functionID, partition, operator, from, to, value, data, operatorData))
       return(hex"A3", "", partition); // Transfer Blocked - Sender lockup period not ended

     uint256 granularity = IERC1400Raw(msg.sender).granularity();
     if(!(value.div(granularity).mul(granularity) == value))
       return(hex"A9", "", partition); // Transfer Blocked - Token granularity

     return(hex"A2", "", partition);  // Transfer Verified - Off-Chain approval for restricted token
   }

  /**
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   */
  function canTransfer(bytes4 /*functionID*/, address /*operator*/, address /*from*/, address /*to*/, uint256 /*value*/, bytes calldata /*data*/, bytes calldata /*operatorData*/)
    external
    view
    returns (byte, bytes32)
  {
    // if(!IERC1400Raw(msg.sender).isOperator(operator, from))
    //    return(hex"A7", ""); // Transfer Blocked - Identity restriction

    // byte esc;

    // bytes32[] memory defaultPartitions = IERC1400Partition(msg.sender).getDefaultPartitions();

    // if(defaultPartitions.length == 0) {
    //   return(hex"A8", ""); // Transfer Blocked - Token restriction
    // }

    // uint256 _remainingValue = value;
    // uint256 _localBalance;

    // for (uint i = 0; i < defaultPartitions.length; i++) {
    //   _localBalance = IERC1400Partition(msg.sender).balanceOfByPartition(defaultPartitions[i], from);
    //   if(_remainingValue <= _localBalance) {
    //     (esc,,) = _canTransferByPartition(functionID, defaultPartitions[i], operator, from, to, _remainingValue, data, operatorData);
    //     _remainingValue = 0;
    //     break;
    //   } else if (_localBalance != 0) {
    //     (esc,,) = _canTransferByPartition(functionID, defaultPartitions[i], operator, from, to, _localBalance, data, operatorData);
    //     _remainingValue = _remainingValue - _localBalance;
    //   }
    //   if(esc != hex"A2") {
    //     return(esc, "");
    //   }
    // }

    // if(_remainingValue != 0) {
    //   return(hex"A8", ""); // Transfer Blocked - Token restriction
    // }

    // return(hex"A2", ""); // Transfer Verified - Off-Chain approval for restricted token

    return(hex"00", "");
  }

}