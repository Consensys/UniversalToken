pragma solidity ^0.8.0;

import {TransferData} from "./ERC20ExtendableLib.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC20Extension is IERC165 {

    function validateTransfer(TransferData memory data) external view returns (bool);

    function onTransferExecuted(TransferData memory data) external returns (bool);
}