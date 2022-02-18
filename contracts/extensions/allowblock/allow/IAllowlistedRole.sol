pragma solidity ^0.8.0;

interface IAllowlistedRole {
    event AllowlistedAdded(address indexed account);
    event AllowlistedRemoved(address indexed account);

    function isAllowlisted(address account) external view returns (bool);
    
    function addAllowlisted(address account) external;

    function removeAllowlisted(address account) external;
}