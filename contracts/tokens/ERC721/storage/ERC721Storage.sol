pragma solidity ^0.8.0;

import {TokenStorage} from "../../storage/TokenStorage.sol";
import {ERC721TokenInterface} from "../ERC721TokenInterface.sol";

contract ERC721Storage is ERC721TokenInterface, TokenStorage {
    constructor(address token) TokenStorage(token) { }
}