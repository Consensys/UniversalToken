pragma solidity ^0.8.0;

interface IAllowlistedAdminRole {
    event AllowlistedAdminAdded(address indexed account);
    event AllowlistedAdminRemoved(address indexed account);

    function isAllowlistedAdmin(address account) external view returns (bool);
    
    function addAllowlistedAdmin(address account) external;

    function removeAllowlisitedAdmin(address account) external;

    modifier onlyAllowlistedAdmin {
        require(this.isAllowlistedAdmin(msg.sender), "Not an allow list admin");
        _;
    }
}