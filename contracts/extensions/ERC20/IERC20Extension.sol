pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IExtension} from "../IExtension.sol";
import {TransferData} from "../../tokens/IToken.sol";

interface IERC20Extension is IExtension, IERC165 {
    function validateTransfer(TransferData memory data) external view returns (bool);

    function onTransferExecuted(TransferData memory data) external returns (bool);
}