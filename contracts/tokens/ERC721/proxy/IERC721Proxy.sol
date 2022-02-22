pragma solidity ^0.8.0;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ITokenProxy} from "../../ITokenProxy.sol";

interface IERC721Proxy is IERC721Metadata, ITokenProxy {
    function mintingAllowed() external view returns (bool);

    function burningAllowed() external view returns (bool);
    
    function burn(uint256 tokenId) external returns (bool);
}