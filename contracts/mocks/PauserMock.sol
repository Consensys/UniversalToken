// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotPausered" MODIFIER

import "../roles/PauserRole.sol";


contract PauserMock is PauserRole {

  bool _mockActivated;

  constructor(address token) {
    _addPauser(token, msg.sender);
  }

  function mockFunction(address token, bool mockActivated) external onlyPauser(token) {
    _mockActivated = mockActivated;
  }

}