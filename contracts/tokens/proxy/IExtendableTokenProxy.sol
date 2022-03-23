pragma solidity ^0.8.0;

import {ITokenProxy} from "./ITokenProxy.sol";
import {IExtendable} from "../extension/IExtendable.sol";

interface IExtendableTokenProxy is ITokenProxy, IExtendable {
}