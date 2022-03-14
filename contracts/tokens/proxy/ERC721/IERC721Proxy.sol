pragma solidity ^0.8.0;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ITokenProxy} from "../../../interface/ITokenProxy.sol";

interface IERC721Proxy is IERC721Metadata, ITokenProxy {
    function mintingAllowed() external view returns (bool);

    function burningAllowed() external view returns (bool);
    
    function burn(uint256 tokenId) external returns (bool);

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);

    /**
    * @dev Function to mint tokens
    * @param to The address that will receive the minted tokens.
    * @param tokenId The token id to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address to, uint256 tokenId) external returns (bool);
    
    function mintAndSetTokenURI(address to, uint256 tokenId, string memory uri) external returns (bool);

    function setTokenURI(uint256 tokenId, string memory uri) external;

    function setContractURI(string memory uri) external;

    function contractURI() external view returns (string memory);
}