pragma solidity ^0.8.0;

interface IRegisteredFunctionLookup {
    /**
    * @notice An array of function signatures this extension adds when
    * registered when a TokenProxy
    * @dev This function is used by the TokenProxy to determine what
    * function selectors to add to the TokenProxy
    */
    function externalFunctions() external view returns (bytes4[] memory);
}