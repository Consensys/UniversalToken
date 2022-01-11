pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IProxyContext} from "../../../tools/context/IProxyContext.sol";

interface IERC20Storage is IERC20Metadata, IProxyContext {
    function burn(uint256 amount) external returns (bool);

    function mint(address receipient, uint256 amoount) external returns (bool);

    function burnFrom(address account, uint256 amount) external returns (bool);

    function decreaseAllowance(address spender, uint256 amount) external returns (bool);

    function increaseAllowance(address spender, uint256 amount) external returns (bool);

    function registerExtension(address extension) external returns (bool);

    function removeExtension(address extension) external returns (bool);

    function disableExtension(address extension) external returns (bool);

    function enableExtension(address extension) external returns (bool);

    function allExtensions() external view returns (address[] memory);
}