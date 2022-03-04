pragma solidity ^0.8.0;

import {TokenStorage} from "../../storage/TokenStorage.sol";
import {ERC1155TokenInterface} from "../ERC1155TokenInterface.sol";

contract ERC721Storage is ERC1155TokenInterface, TokenStorage {
    constructor(address token) TokenStorage(token) { }
}