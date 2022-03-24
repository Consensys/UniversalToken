pragma solidity ^0.8.0;

import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";

/**
* @title ERC1820 Provider for ERC1155
* @notice This should be inherited by the token proxy & token logic contracts
* @dev A base contract that inherits from TokenERC1820Provider and implements
* the interface name functions for ERC1155
*/
abstract contract ERC1155TokenInterface is TokenERC1820Provider {
    string constant internal ERC1155_INTERFACE_NAME = "ERC721Token";
    string constant internal ERC1155_LOGIC_INTERFACE_NAME = "ERC721TokenLogic";

    /**
    * @dev The interface name for the token logic contract to be used in ERC1820.
    * @return string ERC1155TokenLogic
    */
    function __tokenLogicInterfaceName() internal pure override returns (string memory) {
        return ERC1155_LOGIC_INTERFACE_NAME;
    }

    /**
    * @dev The interface name for the token logic contract to be used in ERC1820.
    * @return string ERC1155Token
    */
    function __tokenInterfaceName() internal pure override returns (string memory) {
        return ERC1155_INTERFACE_NAME;
    }
}