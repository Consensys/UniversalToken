pragma solidity ^0.5.0;

import "./ERC1400Raw.sol";
import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";


/**
 * @title ERC1400RawIssuable
 * @dev ERC1400Raw issuance logic
 */
contract ERC1400RawIssuable is ERC1400Raw, MinterRole {

  /**
   * [NOT MANDATORY FOR ERC1400Raw STANDARD]
   * @dev Issue the amout of tokens for the recipient 'to'.
   * @param to Token recipient.
   * @param value Number of tokens issued.
   * @param data Information attached to the issuance, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return A boolean that indicates if the operation was successful.
   */
  function issue(address to, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
    onlyMinter
    returns (bool)
  {
    _issue("", msg.sender, to, value, data, "");

    return true;
  }

}
