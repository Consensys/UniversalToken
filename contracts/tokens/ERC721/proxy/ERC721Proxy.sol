pragma solidity ^0.8.0;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Proxy} from "./IERC721Proxy.sol";
import {IERC721Logic} from "../logic/IERC721Logic.sol";
import {ERC721Storage} from "../storage/ERC721Storage.sol";
import {IToken, TokenStandard, TransferData} from "../../IToken.sol";
import {TokenProxy} from "../../proxy/TokenProxy.sol";
import {ERC721TokenInterface} from "../ERC721TokenInterface.sol";

contract ERC721Proxy is IERC721Proxy, TokenProxy, ERC721TokenInterface {
    bytes32 constant ERC721_TOKEN_META = keccak256("erc721.token.meta");

    struct TokenMeta {
        bool initialized;
        string name;
        string symbol;
        uint256 maxSupply;
        bool allowMint;
        bool allowBurn;
    }

    constructor(
        string memory name_, string memory symbol_, 
        bool allowMint, bool allowBurn, address owner,
        uint256 maxSupply_, address logicAddress
    ) TokenProxy(logicAddress, owner) { 
        require(maxSupply_ > 0, "Max supply must be non-zero");

        if (allowMint) {
            _addRole(owner, TOKEN_MANAGER_ADDRESS);
        }

        TokenMeta storage m = _getTokenMeta();
        m.name = name_;
        m.symbol = symbol_;
        m.maxSupply = maxSupply_;
        m.allowMint = allowMint;
        m.allowBurn = allowBurn;
        
        ERC721Storage store = new ERC721Storage(address(this));
        _setStorage(address(store));

        //Update the doamin seperator now that 
        //we've setup everything
        _updateDomainSeparator();

        m.initialized = true;
    }

    function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }
    
    modifier mintingEnabled {
        require(mintingAllowed(), "Minting is disabled");
        _;
    }

    modifier burningEnabled {
        require(burningAllowed(), "Burning is disabled");
        _;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function _getTokenMeta() internal pure returns (TokenMeta storage r) {
        bytes32 slot = ERC721_TOKEN_META;
        assembly {
            r.slot := slot
        }
    }

    function _getStorageContract() internal view returns (IERC721Logic) {
        return IERC721Logic(_getStorageContractAddress());
    }

    function mintingAllowed() public override view returns (bool) {
        TokenMeta storage m = _getTokenMeta();
        return m.allowMint;
    }

    function burningAllowed() public override view returns (bool) {
        TokenMeta storage m = _getTokenMeta();
        return m.allowBurn;
    }

    function _toggleMinting(bool allowMinting) internal {
        TokenMeta storage m = _getTokenMeta();
        m.allowMint = allowMinting;
    }

    function _toggleBurning(bool allowBurning) internal {
        TokenMeta storage m = _getTokenMeta();
        m.allowBurn = allowBurning;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public override view returns (uint256) {
        return _getStorageContract().balanceOf(account);
    }

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external override view returns (address owner) {
        return _getStorageContract().ownerOf(tokenId);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public override view returns (string memory) {
        return _getTokenMeta().name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public override view returns (string memory) {
        return _getTokenMeta().symbol;
    }

    function tokenURI(uint256 tokenId) external override view returns (string memory) {
        return _getStorageContract().tokenURI(tokenId);
    }

    /**
     * @dev Performs a controlled transfer of tokens given a TransferData struct.
     * Under the hood, this will Safely transfers `tokenId` token from `from` to `to`, 
     * checking first that contract recipients are aware of the ERC721 protocol to 
     * prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - The caller must have the controller role
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function tokenTransfer(TransferData calldata td) external override onlyControllers returns (bool) {
        require(td.token == address(this), "Invalid token");

        if (td.partition != bytes32(0)) {
            return false; //We cannot do partition transfers
        }

        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(td.from, td.to, td.tokenId);
        }

        return result;
    }

    //TODO Add mint

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public override virtual burningEnabled returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(_msgSender(), address(0), tokenId);
        }
        return result;
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(from, to, tokenId);
        }
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(from, to, tokenId);
        }
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external override view returns (address operator) {
        return _getStorageContract().getApproved(tokenId);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) public override {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Approval(_msgSender(), to, tokenId);
        }
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external override {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit ApprovalForAll(_msgSender(), operator, _approved);
        }
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external override view returns (bool) {
        return _getStorageContract().isApprovedForAll(owner, operator);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external override {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(from, to, tokenId);
        }
    }

    function _transfer(TransferData memory td) private returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IToken.tokenTransfer.selector, td));
        return result;
    }

    function _burn(uint256 amount) private returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC721Proxy.burn.selector, amount));
        return result;
    }

    function _domainName() internal virtual override view returns (bytes memory) {
        return bytes(name());
    }
    
    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC721;
    }
}