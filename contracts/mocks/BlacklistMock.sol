pragma solidity ^0.5.0;

// MOCK CONTRACT TO REACH FULL COVERAGE BY CALLING "onlyNotBlacklisted" MODIFIER

import "../tokenExtension/roles/BlacklistedRole.sol";

contract BlacklistMock is BlacklistedRole {

  bool _blacklistActivated;

  constructor() public {}

  /**
   * @dev Know if blacklist feature is activated.
   * @return bool 'true' if blakclist feature is activated, 'false' if not.
   */
  function isBlacklistActivated() external view returns (bool) {
    return _blacklistActivated;
  }

  /**
   * @dev Set blacklist activation status.
   * @param blacklistActivated 'true' if blacklist shall be activated, 'false' if not.
   */
  function setBlacklistActivated(bool blacklistActivated) external onlyNotBlacklisted {
    _blacklistActivated = blacklistActivated;
  }

}