pragma solidity ^0.8.0;

import {DynamicTokenInterface} from "../DynamicTokenInterface.sol";

abstract contract ERC20TokenInterface is DynamicTokenInterface {
    string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
    string constant internal ERC20_STORAGE_INTERFACE_NAME = "ERC20TokenStorage";
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";

    function __tokenStorageInterfaceName() internal pure override returns (string memory) {
        return ERC20_STORAGE_INTERFACE_NAME;
    }

    function __tokenLogicInterfaceName() internal pure override returns (string memory) {
        return ERC20_LOGIC_INTERFACE_NAME;
    }

    function __tokenInterfaceName() internal virtual override pure returns (string memory) {
        return ERC20_INTERFACE_NAME;
    }
}