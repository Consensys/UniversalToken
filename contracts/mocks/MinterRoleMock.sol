// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyMinter" MODIFIER

import "../roles/MinterRole.sol";


contract MinterMock is MinterRole {

  constructor() MinterRole() {}

}