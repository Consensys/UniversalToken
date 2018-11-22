pragma solidity ^0.4.24;

/// @title IERC1400 Security Token Standard (EIP 1400)
/// @dev See https://github.com/SecurityTokenStandard/EIP-Spec

interface IERC1400  {

    // Document Management
    function getDocument(bytes32 name) external view returns (string, bytes32); // 1/8
    function setDocument(bytes32 name, string uri, bytes32 documentHash) external; // 2/8

    // Controller Operation
    function isControllable() external view returns (bool); // 3/8

    // Token Issuance
    function isIssuable() external view returns (bool); // 4/8
    function issueByTranche(bytes32 tranche, address tokenHolder, uint256 amount, bytes data) external; // 5/8
    event IssuedByTranche(bytes32 indexed tranche, address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);

    // Token Redemption
    function redeemByTranche(bytes32 tranche, uint256 amount, bytes data) external; // 6/8
    function operatorRedeemByTranche(bytes32 tranche, address tokenHolder, uint256 amount, bytes data, bytes operatorData) external; // 7/8
    event RedeemedByTranche(bytes32 indexed tranche, address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);

    // Transfer Validity
    function canSend(address from, address to, bytes32 tranche, uint256 amount, bytes data) external view returns (byte, bytes32, bytes32); // 8/8

}


/*
Reason codes - ERC1066

To improve the token holder experience, canSend MUST return a reason byte code
on success or failure based on the EIP-1066 application-specific status codes specified below.
An implementation can also return arbitrary data as a bytes32 to provide additional
information not captured by the reason code.

Code	Reason
0xA0	Transfer Verified - Unrestricted
0xA1	Transfer Verified - On-Chain approval for restricted token
0xA2	Transfer Verified - Off-Chain approval for restricted token
0xA3	Transfer Blocked - Sender lockup period not ended
0xA4	Transfer Blocked - Sender balance insufficient
0xA5	Transfer Blocked - Sender not eligible
0xA6	Transfer Blocked - Receiver not eligible
0xA7	Transfer Blocked - Identity restriction
0xA8	Transfer Blocked - Token restriction
0xA9	Transfer Blocked - Token granularity
*/
