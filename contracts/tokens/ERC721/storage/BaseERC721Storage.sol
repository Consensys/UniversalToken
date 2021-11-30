pragma solidity ^0.8.0;

import {IERC721Storage} from "./IERC721Storage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract BaseERC721Storage is IERC721Storage, AccessControl {
    //using Address for address;
    //using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(uint256 => string) private _tokenURIs;

    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    string private _baseURI;

    address private _currentWriter;
    address private _admin;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentWriter = _admin = msg.sender;
    }

    modifier onlyWriter {
        require(_currentWriter == msg.sender, "Only writers can execute this function");
        _;
    }

    modifier onlyAdmin {
        require(_admin == msg.sender, "Only writers can execute this function");
        _;
    }

    function changeCurrentWriter(address newWriter) external override onlyAdmin {
        _currentWriter = newWriter;
    }

    function ownerOf(uint256 tokenId) external override view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function getApproved(uint256 tokenId) external override view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    function exists(uint256 tokenId) external override view returns (bool) {
        return _exists(tokenId);
    }

    function isApprovedForAll(address owner, address operator) external override view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function tokenURI(uint256 tokenId) external override view returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI;

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return "";
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external override view returns (uint256) {
        require(account != address(0), "ERC721: balance query for the zero address");
        return _balances[account];
    }

    function setOwnerOf(uint256 tokenId, address newOwner) external override onlyWriter returns (bool) {
        _owners[tokenId] = newOwner;
    }

    function setTokenURI(uint256 tokenId, string memory uri) external override onlyWriter returns (bool) {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = uri;
    }

    function setApprove(uint256 tokenId, address to, bool approved) external override onlyWriter returns (bool) {
        require(_exists(tokenId), "ERC721: token does not exist");
        address owner = _owners[tokenId];
        require(to != owner, "ERC721: approval to current owner");

/*         require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        ); */

        _tokenApprovals[tokenId] = to;
    }

    function setApprovalForAll(address operator, address owner, bool approved) external override onlyWriter returns (bool) {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external override view returns (uint256) {
        require(index < _balances[owner], "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    function tokenByIndex(uint256 index) external override view returns (uint256) {
        require(index < _allTokens.length, "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    function totalSupply() external override view returns (uint256) {
        return _allTokens.length;
    }

    function baseURI() external override view returns (string memory) {
        return _baseURI;
    }

    function setBaseURI(string memory baseURI) external override onlyWriter returns (bool) {
        _baseURI = baseURI;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() external override view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external override view returns (string memory) {
        return _symbol;
    }

    function setBalance(address owner, uint256 amount) external override onlyWriter returns (bool) {
        _balances[owner] = amount;
        return true;
    }

    function addTokenToOwnerEnumeration(address to, uint256 tokenId) external override onlyWriter returns (bool) {
        uint256 length = _balances[to];
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function addTokenToAllTokensEnumeration(uint256 tokenId) external override onlyWriter returns (bool) {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function removeTokenFromOwnerEnumeration(address from, uint256 tokenId) external override onlyWriter returns (bool) {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _balances[from] - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    function removeTokenFromAllTokensEnumeration(uint256 tokenId) external override onlyWriter returns (bool) {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }

    function allowWriteFrom(address source) external override view returns (bool) {
        return _currentWriter == source;
    }
}