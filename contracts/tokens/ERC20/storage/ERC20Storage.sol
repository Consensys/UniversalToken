pragma solidity ^0.8.0;

import {TokenStorage} from "../../storage/TokenStorage.sol";
import {ERC20TokenInterface} from "../ERC20TokenInterface.sol";

contract ERC20Storage is ERC20TokenInterface, TokenStorage {
    constructor(address token) TokenStorage(token) { }
}