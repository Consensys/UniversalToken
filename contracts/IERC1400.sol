// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// ****************** Document Management *******************
import "./interface/IERC1643.sol";

/**
 * @title IERC1400 security token standard
 * @dev See https://github.com/SecurityTokenStandard/EIP-Spec/blob/master/eip/eip-1400.md
 */
interface IERC1400 is IERC20, IERC1643 {

  // ******************* Token Information ********************
  function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256);
  function partitionsOf(address tokenHolder) external view returns (bytes32[] memory);

  // *********************** Transfers ************************
  function transferWithData(address to, uint256 value, bytes calldata data) external;
  function transferFromWithData(address from, address to, uint256 value, bytes calldata data) external;

  // *************** Partition Token Transfers ****************
  function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external returns (bytes32);
  function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bytes32);
  function allowanceByPartition(bytes32 partition, address owner, address spender) external view returns (uint256);

  // ****************** Controller Operation ******************
  function isControllable() external view returns (bool);
  // function controllerTransfer(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external; // removed because same action can be achieved with "operatorTransferByPartition"
  // function controllerRedeem(address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData) external; // removed because same action can be achieved with "operatorRedeemByPartition"

  // ****************** Operator Management *******************
  function authorizeOperator(address operator) external;
  function revokeOperator(address operator) external;
  function authorizeOperatorByPartition(bytes32 partition, address operator) external;
  function revokeOperatorByPartition(bytes32 partition, address operator) external;

  // ****************** Operator Information ******************
  function isOperator(address operator, address tokenHolder) external view returns (bool);
  function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool);

  // ********************* Token Issuance *********************
  function isIssuable() external view returns (bool);
  function issue(address tokenHolder, uint256 value, bytes calldata data) external;
  function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external;

  // ******************** Token Redemption ********************
  function redeem(uint256 value, bytes calldata data) external;
  function redeemFrom(address tokenHolder, uint256 value, bytes calldata data) external;
  function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external;
  function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata operatorData) external;

  // ******************* Transfer Validity ********************
  // We use different transfer validity functions because those described in the interface don't allow to verify the certificate's validity.
  // Indeed, verifying the ecrtificate's validity requires to keeps the function's arguments in the exact same order as the transfer function.
  //
  // function canTransfer(address to, uint256 value, bytes calldata data) external view returns (byte, bytes32);
  // function canTransferFrom(address from, address to, uint256 value, bytes calldata data) external view returns (byte, bytes32);
  // function canTransferByPartition(address from, address to, bytes32 partition, uint256 value, bytes calldata data) external view returns (byte, bytes32, bytes32);    

  // ******************* Controller Events ********************
  // We don't use this event as we don't use "controllerTransfer"
  //   event ControllerTransfer(
  //       address controller,
  //       address indexed from,
  //       address indexed to,
  //       uint256 value,
  //       bytes data,
  //       bytes operatorData
  //   );
  //
  // We don't use this event as we don't use "controllerRedeem"
  //   event ControllerRedemption(
  //       address controller,
  //       address indexed tokenHolder,
  //       uint256 value,
  //       bytes data,
  //       bytes operatorData
  //   );

  // ******************** Transfer Events *********************
  event TransferByPartition(
      bytes32 indexed fromPartition,
      address operator,
      address indexed from,
      address indexed to,
      uint256 value,
      bytes data,
      bytes operatorData
  );

  event ChangedPartition(
      bytes32 indexed fromPartition,
      bytes32 indexed toPartition,
      uint256 value
  );

  // ******************** Operator Events *********************
  event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
  event RevokedOperator(address indexed operator, address indexed tokenHolder);
  event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
  event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

  // ************** Issuance / Redemption Events **************
  event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
  event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);
  event IssuedByPartition(bytes32 indexed partition, address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);
  event RedeemedByPartition(bytes32 indexed partition, address indexed operator, address indexed from, uint256 value, bytes operatorData);

}

/**
 * Reason codes - ERC-1066
 *
 * To improve the token holder experience, canTransfer MUST return a reason byte code
 * on success or failure based on the ERC-1066 application-specific status codes specified below.
 * An implementation can also return arbitrary data as a bytes32 to provide additional
 * information not captured by the reason code.
 * 
 * Code	Reason
 * 0x50	transfer failure
 * 0x51	transfer success
 * 0x52	insufficient balance
 * 0x53	insufficient allowance
 * 0x54	transfers halted (contract paused)
 * 0x55	funds locked (lockup period)
 * 0x56	invalid sender
 * 0x57	invalid receiver
 * 0x58	invalid operator (transfer agent)
 * 0x59	
 * 0x5a	
 * 0x5b	
 * 0x5a	
 * 0x5b	
 * 0x5c	
 * 0x5d	
 * 0x5e	
 * 0x5f	token meta or info
 *
 * These codes are being discussed at: https://ethereum-magicians.org/t/erc-1066-ethereum-status-codes-esc/283/24
 */