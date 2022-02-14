pragma solidity ^0.8.0;

import {TokenStandard} from "../tokens/IToken.sol";

interface IExtensionMetadata {
    function externalFunctions() external view returns (bytes4[] memory);
    
    function requiredRoles() external view returns (bytes32[] memory);

    function isTokenStandardSupported(TokenStandard standard) external view returns (bool);
}