pragma solidity ^0.8.0;

interface IERC721Storage {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    function ownerOf(uint256 tokenId) external view returns (address);

    function exists(uint256 tokenId) external view returns (bool);

    function getApproved(uint256 tokenId) external view returns (address);

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function baseURI() external view returns (string memory);

    function setBaseURI(string memory baseURI) external returns (bool);

    function changeCurrentWriter(address newWriter) external;

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    function setBalance(address owner, uint256 amount) external returns (bool);

    function allowWriteFrom(address source) external view returns (bool);

    function setOwnerOf(uint256 tokenId, address newOwner) external returns (bool);

    function setTokenURI(uint256 tokenId, string memory uri) external returns (bool);

    function setApprove(uint256 tokenId, address to, bool approved) external returns (bool);

    function setApprovalForAll(address operator, address owner, bool approved) external returns (bool);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function addTokenToOwnerEnumeration(address to, uint256 tokenId) external returns (bool);

    function addTokenToAllTokensEnumeration(uint256 tokenId) external returns (bool);

    function removeTokenFromOwnerEnumeration(address from, uint256 tokenId) external returns (bool);

    function removeTokenFromAllTokensEnumeration(uint256 tokenId) external returns (bool);
}