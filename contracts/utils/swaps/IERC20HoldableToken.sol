/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20HoldData, HoldStatusCode, IHoldableToken} from "../../extensions/holds/IHoldableToken.sol";

/**
 * @title Holdable ERC20 Token Interface.
 * @dev like approve except the tokens can't be spent by the sender while they are on hold.
 */
interface IERC20HoldableToken is IHoldableToken, IERC20 { }