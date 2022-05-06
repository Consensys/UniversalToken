pragma solidity ^0.8.0;

import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";

/**
* @title ERC1820 Provider for ERC20
* @notice This should be inherited by the token proxy & token logic contracts
* @dev A base contract that inherits from TokenERC1820Provider and implements
* the interface name functions for ERC20
*/
abstract contract ERC20TokenInterface is TokenERC1820Provider {
    string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";

    /**
    * @dev The interface name for the token logic contract to be used in ERC1820.
    * @return string ERC20TokenLogic
    */
    function __tokenLogicInterfaceName() internal pure override returns (string memory) {
        return ERC20_LOGIC_INTERFACE_NAME;
    }

    /**
    * @dev The interface name for the token logic contract to be used in ERC1820.
    * @return string ERC20Token
    */
    function __tokenInterfaceName() internal virtual override pure returns (string memory) {
        return ERC20_INTERFACE_NAME;
    }
}