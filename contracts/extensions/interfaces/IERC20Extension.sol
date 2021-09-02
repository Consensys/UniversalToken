pragma solidity ^0.8.0;

interface IERC20Extension {
    function externalFunctions() external pure returns (bytes4[] memory);

    function initalize() external;

    function validateTokenTransfer(address from, address recipient, uint256 amount) external view returns (bool);

    function validateTokenApproval(address from, address spender, uint256 amount) external view returns (bool);
}