pragma solidity ^0.5.0;

import "../extensions/tokenExtensions/ERC1400TokensValidator.sol";

/**
 @notice Interface to the Minterrole contract
*/
interface IMinterRoleMock {
  function renounceMinter() external;
}

contract ERC1400TokensValidatorMock is ERC1400TokensValidator {

  constructor(bool whitelistActivated, bool blacklistActivated, bool holdsActivated, bool selfHoldsActivated)
    public ERC1400TokensValidator(whitelistActivated, blacklistActivated, holdsActivated, selfHoldsActivated)
  {}

  function renounceMinter(address token) external onlyOwner {
    IMinterRoleMock(token).renounceMinter();
  }

}