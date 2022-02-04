pragma solidity ^0.8.0;

import {TransferData} from "../tokens/IToken.sol";
import {IExtensionMetadata, TokenStandard} from "./IExtensionMetadata.sol";

interface IExtension is IExtensionMetadata {
    function initalize() external;

    function onTransferExecuted(TransferData memory data) external returns (bool);
}