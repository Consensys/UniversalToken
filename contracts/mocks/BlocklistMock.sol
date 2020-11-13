pragma solidity ^0.5.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotBlocklisted" MODIFIER

import "../roles/BlocklistedRole.sol";


contract BlocklistMock is BlocklistedRole {

  bool _mockActivated;

  constructor(address token) public {
    _addBlocklistAdmin(token, msg.sender);
  }

  function mockFunction(address token, bool mockActivated) external onlyNotBlocklisted(token) {
    _mockActivated = mockActivated;
  }

}