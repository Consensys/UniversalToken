pragma solidity ^0.8.0;

import {ERC20Core} from "../implementation/core/ERC20Core.sol";
import {ERC20CoreExtendableBase} from "./ERC20CoreExtendableBase.sol";


contract ERC20CoreExtendable is ERC20CoreExtendableBase {
    constructor(address proxy, address store) ERC20Core(proxy, store) { }
}