pragma solidity ^0.8.0;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IToken} from "../../IToken.sol";
import {ITokenRoles} from "../../roles/ITokenRoles.sol";

interface IERC721Proxy is IERC721Metadata, IToken, ITokenRoles {
    function mintingAllowed() external view returns (bool);

    function burningAllowed() external view returns (bool);

    function domainName() external view returns (bytes memory);

    function domainVersion() external view returns (bytes32);

    function upgradeTo(address implementation) external;

    function registerExtension(address extension) external returns (bool);

    function removeExtension(address extension) external returns (bool);

    function disableExtension(address extension) external returns (bool);

    function enableExtension(address extension) external returns (bool);

    function allExtensions() external view returns (address[] memory);
    
    function burn(uint256 tokenId) external returns (bool);

    function contextAddressForExtension(address extension) external view returns (address);
}