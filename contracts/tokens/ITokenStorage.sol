pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";
import {IExtensionStorage} from "./extension/IExtensionStorage.sol";

interface ITokenStorage is IExtensionStorage, IToken { }