pragma solidity ^0.8.0;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ITokenLogic} from "../../ITokenLogic.sol";

interface IERC721Logic is IERC721Metadata, ITokenLogic {
    function burn(uint256 amount) external returns (bool);
}