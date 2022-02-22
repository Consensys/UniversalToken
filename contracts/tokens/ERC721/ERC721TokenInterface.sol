pragma solidity ^0.8.0;

import {DynamicTokenInterface} from "../DynamicTokenInterface.sol";

abstract contract ERC721TokenInterface is DynamicTokenInterface {
    string constant internal ERC721_INTERFACE_NAME = "ERC721Token";
    string constant internal ERC721_STORAGE_INTERFACE_NAME = "ERC721TokenStorage";
    string constant internal ERC721_LOGIC_INTERFACE_NAME = "ERC721TokenLogic";

    function __tokenStorageInterfaceName() internal pure override returns (string memory) {
        return ERC721_STORAGE_INTERFACE_NAME;
    }

    function __tokenLogicInterfaceName() internal pure override returns (string memory) {
        return ERC721_LOGIC_INTERFACE_NAME;
    }

    function __tokenInterfaceName() internal pure override returns (string memory) {
        return ERC721_INTERFACE_NAME;
    }
}