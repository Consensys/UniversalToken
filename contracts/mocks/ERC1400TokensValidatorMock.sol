// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../extensions/tokenExtensions/ERC1400TokensValidator.sol";

/**
 @notice Interface to the Minterrole contract
*/
interface IMinterMock {
  function renounceMinter() external;
}

contract ERC1400TokensValidatorMock is ERC1400TokensValidator {

  function renounceMinter(address token) external onlyTokenController(token) {
    IMinterMock(token).renounceMinter();
  }

}