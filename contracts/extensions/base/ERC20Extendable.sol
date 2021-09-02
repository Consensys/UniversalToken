pragma solidity ^0.8.0;

import {ERC20ExtendableWithDiamondCut} from "./ERC20ExtendableWithDiamondCut.sol";

contract ERC20Extendable is ERC20ExtendableWithDiamondCut {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    constructor(string memory name, string memory symbol, uint8 decimals) 
        payable
        ERC20ExtendableWithDiamondCut(name, symbol, decimals, msg.sender, ZERO_ADDRESS) { }
}