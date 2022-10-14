// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// MOCK CONTRACT TO RETRIEVE TIME ON CHAIN

contract ClockMock {

  constructor() {}

  /**
   * @dev Get time on chain.
   * @return block.timestamp.
   */
  function getTime() external view returns (uint256) {
    return block.timestamp;
  }

}