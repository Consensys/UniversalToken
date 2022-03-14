pragma solidity ^0.8.0;

import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";

abstract contract ERC20TokenInterface is TokenERC1820Provider {
    string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";

    function __tokenLogicInterfaceName() internal pure override returns (string memory) {
        return ERC20_LOGIC_INTERFACE_NAME;
    }

    function __tokenInterfaceName() internal virtual override pure returns (string memory) {
        return ERC20_INTERFACE_NAME;
    }
}