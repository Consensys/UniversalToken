// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotAllowlisted" MODIFIER

import "../roles/AllowlistedRole.sol";


contract AllowlistMock is AllowlistedRole {

  bool _mockActivated;

  constructor(address token) {
    _addAllowlistAdmin(token, msg.sender);
  }

  function mockFunction(address token, bool mockActivated) external onlyNotAllowlisted(token) {
    _mockActivated = mockActivated;
  }

}