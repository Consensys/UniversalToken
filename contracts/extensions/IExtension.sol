pragma solidity ^0.8.0;

import {TransferData} from "../tokens/IToken.sol";

interface IExtension {
    function initalize() external;

    function externalFunctions() external view returns (bytes4[] memory);
    
    function requiredRoles() external view returns (bytes32[] memory);

    function onTransferExecuted(TransferData memory data) external returns (bool);
}