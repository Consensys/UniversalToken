pragma solidity ^0.8.0;

interface IAllowlistedRole {
    event AllowlistedAdded(address indexed account);
    event AllowlistedRemoved(address indexed account);

    function isAllowlisted(address account) external view returns (bool);
    
    function addAllowlisted(address account) external;

    function removeAllowlisited(address account) external;
    
    modifier onlyNotAllowlisted {
        require(!this.isAllowlisted(msg.sender), "Already on allow list");
        _;
    }

    modifier onlyAllowlisted {
        require(this.isAllowlisted(msg.sender), "Not on allow list");
        _;
    }
}