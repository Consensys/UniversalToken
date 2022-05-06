pragma solidity ^0.8.0;

interface IBlocklistedRole {
    event BlocklistedAdded(address indexed account);
    event BlocklistedRemoved(address indexed account);

    function isBlocklisted(address account) external view returns (bool);

    function addBlocklisted(address account) external;

    function removeBlocklisted(address account) external;
}