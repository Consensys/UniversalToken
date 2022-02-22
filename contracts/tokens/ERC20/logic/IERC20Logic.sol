pragma solidity ^0.8.0;

import {ITokenLogic} from "../../ITokenLogic.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20Logic is IERC20Metadata, ITokenLogic {
    function burn(uint256 amount) external returns (bool);

    function mint(address receipient, uint256 amoount) external returns (bool);

    function burnFrom(address account, uint256 amount) external returns (bool);

    function decreaseAllowance(address spender, uint256 amount) external returns (bool);

    function increaseAllowance(address spender, uint256 amount) external returns (bool);
}