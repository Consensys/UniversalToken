pragma solidity ^0.5.0;

import "../extensions/userExtensions/IERC1400TokensSender.sol";
import "../interface/ERC1820Implementer.sol";


contract ERC1400TokensSenderMock is IERC1400TokensSender, ERC1820Implementer {

  string constant internal ERC1400_TOKENS_SENDER = "ERC1400TokensSender";

  constructor() public {
    ERC1820Implementer._setInterface(ERC1400_TOKENS_SENDER);
  }

  function canTransfer(
    bytes4 /*functionSig*/,
    bytes32 /*partition*/,
    address /*operator*/,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
    view
    returns(bool)
  {
    return(_canTransfer(from, to, value, data));
  }

  function tokensToTransfer(
    bytes4 /*functionSig*/,
    bytes32 /*partition*/,
    address /*operator*/,
    address from,
    address to,
    uint value,
    bytes calldata data,
    bytes calldata /*operatorData*/
  ) // Comments to avoid compilation warnings for unused variables.
    external
  {
    require(_canTransfer(from, to, value, data), "A5"); // Transfer Blocked - Sender not eligible
  }

  function _canTransfer(
    address /*from*/,
    address /*to*/,
    uint /*value*/,
    bytes memory data
  ) // Comments to avoid compilation warnings for unused variables.
    internal
    pure
    returns(bool)
  {
    bytes32 transferRevert = 0x1100000000000000000000000000000000000000000000000000000000000000; // Default sender hook failure data for the mock only
    bytes32 data32;
    assembly {
        data32 := mload(add(data, 32))
    }
    if (data32 == transferRevert) {
      return false;
    } else {
      return true;
    }
  }

}


/**
 * Reason codes - ERC1066
 *
 * To improve the token holder experience, canTransfer MUST return a reason byte code
 * on success or failure based on the EIP-1066 application-specific status codes specified below.
 * An implementation can also return arbitrary data as a bytes32 to provide additional
 * information not captured by the reason code.
 *
 * Code	Reason
 * 0xA0	Transfer Verified - Unrestricted
 * 0xA1	Transfer Verified - On-Chain approval for restricted token
 * 0xA2	Transfer Verified - Off-Chain approval for restricted token
 * 0xA3	Transfer Blocked - Sender lockup period not ended
 * 0xA4	Transfer Blocked - Sender balance insufficient
 * 0xA5	Transfer Blocked - Sender not eligible
 * 0xA6	Transfer Blocked - Receiver not eligible
 * 0xA7	Transfer Blocked - Identity restriction
 * 0xA8	Transfer Blocked - Token restriction
 * 0xA9	Transfer Blocked - Token granularity
 */