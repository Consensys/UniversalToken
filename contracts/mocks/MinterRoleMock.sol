pragma solidity ^0.5.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyMinter" MODIFIER

import "../roles/MinterRole.sol";


contract MinterMock is MinterRole {

  constructor() public MinterRole() {}

}