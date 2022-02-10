pragma solidity ^0.8.0;

import {IExtensionStorage} from "../../extension/IExtensionStorage.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IToken} from "../../IToken.sol";

interface IERC721Logic is IERC721Metadata, IExtensionStorage, IToken {
    function burn(uint256 amount) external returns (bool);
}