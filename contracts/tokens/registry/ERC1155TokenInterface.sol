pragma solidity ^0.8.0;

import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";

abstract contract ERC1155TokenInterface is TokenERC1820Provider {
    string constant internal ERC1155_INTERFACE_NAME = "ERC721Token";
    string constant internal ERC1155_LOGIC_INTERFACE_NAME = "ERC721TokenLogic";

    function __tokenLogicInterfaceName() internal pure override returns (string memory) {
        return ERC1155_LOGIC_INTERFACE_NAME;
    }

    function __tokenInterfaceName() internal pure override returns (string memory) {
        return ERC1155_INTERFACE_NAME;
    }
}