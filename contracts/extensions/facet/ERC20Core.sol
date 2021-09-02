pragma solidity ^0.8.0;

import "../../tokens/ERC20Token.sol";
import "../interfaces/IERC20Extension.sol";

contract ERC20CoreFaucet is ERC20Token, IERC20Extension {
    //ANYTHING SET IN THE CONSTRUCTOR WILL BE WRITTEN TO
    //THE IMPLEMENTATION STORAGE, NOT THE BASE CONTRACT STORAGE
    //USE initalize() AS A CONSTRUCTOR
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20Token(name, symbol, decimals) {}

    function externalFunctions() external override pure returns (bytes4[] memory) {
        bytes4[] memory functionSelectors = new bytes4[](10);

        //These functions are called directly and bypass the TokenExtensionFacet
        functionSelectors[0] = ERC20Token.mint.selector;
        functionSelectors[1] = ERC20.name.selector;
        functionSelectors[2] = ERC20.symbol.selector;
        functionSelectors[3] = ERC20.decimals.selector;
        functionSelectors[4] = ERC20Burnable.burn.selector;
        functionSelectors[5] = ERC20Burnable.burnFrom.selector;
        functionSelectors[6] = Pausable.paused.selector;
        functionSelectors[7] = ERC20.increaseAllowance.selector;
        functionSelectors[8] = ERC20.decreaseAllowance.selector;
        functionSelectors[9] = ERC1820Implementer.canImplementInterfaceForAddress.selector;
        

        return functionSelectors;
    }

    function initalize() external override {
        //Anything that the constructor does will not be commited to the base contract storage
        //Therefore, we need to setup basic things here first
        _addMinter(msg.sender);
        ERC1820Implementer._setInterface(ERC20_TOKEN);
    }

    function validateTokenTransfer(address from, address recipient, uint256 amount) external override view returns (bool) {
        return true;
    }

    function validateTokenApproval(address from, address spender, uint256 amount) external override view returns (bool) {
        return true;
    }
}