pragma solidity ^0.4.24;

/// @title IERCST Security Token Standard (EIP 1400)
/// @dev See https://github.com/SecurityTokenStandard/EIP-Spec

import "./IERCPFT.sol";

//TODO: fix interface cannot inherit interface - interface IERCST is IERCPFT
interface IERCST  {

    // Document Management
    function getDocument(bytes32 _name) external view returns (string, bytes32);
    function setDocument(bytes32 _name, string _uri, bytes32 _documentHash) external;

    // Controller Operation
    function isControllable() external view returns (bool);

    // Token Issuance
    function isIssuable() external view returns (bool);
    function issueByTranche(bytes32 _tranche, address _tokenHolder, uint256 _amount, bytes _data) external;
    event IssuedByTranche(bytes32 indexed tranche, address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);

    // Token Redemption
    function redeemByTranche(bytes32 _tranche, uint256 _amount, bytes _data) external;
    function operatorRedeemByTranche(bytes32 _tranche, address _tokenHolder, uint256 _amount, bytes _operatorData) external;
    event RedeemedByTranche(bytes32 indexed tranche, address indexed operator, address indexed from, uint256 amount, bytes operatorData);

    // Transfer Validity
    function canSend(address _from, address _to, bytes32 _tranche, uint256 _amount, bytes _data) external view returns (byte, bytes32, bytes32);

}


/*
Reason codes

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
