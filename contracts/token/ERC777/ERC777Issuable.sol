pragma solidity ^0.4.24;

import "./ERC777.sol";
import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";

/**
 * @title ERC777Issuable
 * @dev ERC777 issuance logic
 */
contract ERC777Issuable is ERC777, MinterRole {

  /**
   * [NOT MANDATORY FOR ERC777 STANDARD]
   * @dev Issue the amout of tokens for the recipient 'to'.
   * @param to Token recipient.
   * @param value Number of tokens issued.
   * @param data Information attached to the issuance, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return A boolean that indicates if the operation was successful.
   */
  function issue(address to, uint256 value, bytes data)
    external
    isValidCertificate(data)
    onlyMinter
    returns (bool)
  {
    _issue(msg.sender, to, value, data, "");

    return true;
  }

}
