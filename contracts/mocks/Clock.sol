pragma solidity ^0.5.0;

// MOCK CONTRACT TO RETRIEVE TIME ON CHAIN

contract ClockMock {

  constructor() public {}

  /**
   * @dev Get time on chain.
   * @return block.timestamp.
   */
  function getTime() external view returns (uint256) {
    return now;
  }

}