pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenExtensionFacet is IERC20 {
    function _initalize(string memory name, string memory symbol, uint8 decimals, address contractOwner) external;

    function registerExtension(address extension) external;

    function removeExtension(address extension) external;
}