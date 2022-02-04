pragma solidity ^0.8.0;

interface IBlocklistedAdminRole {
    event BlocklistedAdminAdded(address indexed account);
    event BlocklistedAdminRemoved(address indexed account);

    function isBlocklistedAdmin(address account) external view returns (bool);

    function addBlocklistedAdmin(address account) external;

    function removeBlocklistedAdmin(address account) external;

    modifier onlyBlocklistedAdmin {
        require(this.isBlocklistedAdmin(msg.sender), "Not on block list admin");
        _;
    }
}