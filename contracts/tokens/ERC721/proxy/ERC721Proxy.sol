pragma solidity ^0.8.0;

import {IERC721Proxy} from "./IERC721Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {TokenRoles} from "../../roles/TokenRoles.sol";
import {DomainAware} from "../../../tools/DomainAware.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {IERC721Logic} from "../logic/IERC721Logic.sol";
import {ERC721Storage} from "../storage/ERC721Storage.sol";
import {ERC721Logic} from "../logic/ERC721Logic.sol";
import {ExtensionStorage} from "../../../extensions/ExtensionStorage.sol";
import {IToken, TokenStandard, TransferData} from "../../IToken.sol";

abstract contract ERC721Proxy is IERC721Proxy, TokenRoles, DomainAware, ERC1820Client, ERC1820Implementer {
    string constant internal ERC721_INTERFACE_NAME = "ERC721Token";
    string constant internal ERC721_STORAGE_INTERFACE_NAME = "ERC721TokenStorage";
    string constant internal ERC721_LOGIC_INTERFACE_NAME = "ERC721TokenLogic";
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
    ) { 
        require(maxSupply_ > 0, "Max supply must be non-zero");
        StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = _msgSender();

        if (owner != _msgSender()) {
            transferOwnership(owner);
        }

        if (allowMint) {
            _addRole(owner, TOKEN_MANAGER_ADDRESS);
        }

        TokenMeta storage m = _getTokenMeta();
        m.name = name_;
        m.symbol = symbol_;
        m.maxSupply = maxSupply_;
        m.allowMint = allowMint;
        m.allowBurn = allowBurn;

        ERC1820Client.setInterfaceImplementation(ERC721_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC721_INTERFACE_NAME); // For migration

        if (logicAddress == address(0)) {
            ERC721Logic logic = new ERC721Logic();
            logicAddress = address(logic);
        }
        require(logicAddress != address(0), "Logic address must be given");
        require(logicAddress == ERC1820Client.interfaceAddr(logicAddress, ERC721_LOGIC_INTERFACE_NAME), "Not registered as a logic contract");

        _setImplementation(logicAddress);
    }

    function initialize() external onlyOwner {
        TokenMeta storage m = _getTokenMeta();
        require(!m.initialized, "This proxy has already been initialized");

        ERC721Storage store = new ERC721Storage(address(this));

        _setStorage(address(store));

        //Update the doamin seperator now that 
        //we've setup everything
        _updateDomainSeparator();

        m.initialized = true;

        _onProxyReady();
    }

    function _onProxyReady() internal virtual { }

    modifier isProxyReady {
        TokenMeta storage m = _getTokenMeta();
        require(m.initialized, "This proxy isnt initialized");
        _;
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

    function _getStorageContract() internal view isProxyReady returns (IERC721Logic) {
        return IERC721Logic(
            ERC1820Client.interfaceAddr(address(this), ERC721_STORAGE_INTERFACE_NAME)
        );
    }

    function _getImplementationContract() internal view returns (address) {
        return ERC1820Client.interfaceAddr(address(this), ERC721_LOGIC_INTERFACE_NAME);
    }

    function _setImplementation(address implementation) internal {
        ERC1820Client.setInterfaceImplementation(ERC721_LOGIC_INTERFACE_NAME, implementation);
    }

    function _setStorage(address store) internal {
        ERC1820Client.setInterfaceImplementation(ERC721_STORAGE_INTERFACE_NAME, store);
    }

    function mintingAllowed() public override view isProxyReady returns (bool) {
        TokenMeta storage m = _getTokenMeta();
        return m.allowMint;
    }

    function burningAllowed() public override view isProxyReady returns (bool) {
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
    function balanceOf(address account) public override view isProxyReady returns (uint256) {
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
    function tokenTransfer(TransferData calldata td) external override onlyControllers isProxyReady returns (bool) {
        require(td.token == address(this), "Invalid token");

        if (td.partition != bytes32(0)) {
            return false; //We cannot do partition transfers
        }

        bool result = _forwardCurrentCall();
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
    function burn(uint256 tokenId) public override virtual burningEnabled isProxyReady returns (bool) {
        bool result = _forwardCurrentCall();
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
    function safeTransferFrom(address from, address to, uint256 tokenId) public override isProxyReady {
        bool result = _forwardCurrentCall();
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
        bool result = _forwardCurrentCall();
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
    function approve(address to, uint256 tokenId) public override isProxyReady {
        bool result = _forwardCurrentCall();
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
        bool result = _forwardCurrentCall();
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
        bool result = _forwardCurrentCall();
        if (result) {
            emit Transfer(from, to, tokenId);
        }
    }

    function _transfer(TransferData memory td) private returns (bool) {
        return _forwardCall(abi.encodeWithSelector(IToken.tokenTransfer.selector, td));
    }

    function _burn(uint256 amount) private returns (bool) {
        return _forwardCall(abi.encodeWithSelector(IERC721Proxy.burn.selector, amount));
    }

    function domainName() public virtual override(DomainAware, IERC721Proxy) view returns (bytes memory) {
        return bytes(name());
    }

    function domainVersion() public virtual override(DomainAware, IERC721Proxy) view returns (bytes32) {
        return bytes32(uint256(uint160(address(_getImplementationContract()))));
    }

    function upgradeTo(address implementation) external override onlyManager {
        _setImplementation(implementation);
    }

    function registerExtension(address extension) external override onlyManager isProxyReady returns (bool) {
        bool result = _getStorageContract().registerExtension(extension);
        if (result) {
            address contextAddress = _getStorageContract().contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _addRole(ctxAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function removeExtension(address extension) external override onlyManager isProxyReady returns (bool) {
       bool result = _getStorageContract().removeExtension(extension);

       if (result) {
            address contextAddress = _getStorageContract().contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _addRole(ctxAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function disableExtension(address extension) external override onlyManager isProxyReady returns (bool) {
        return _getStorageContract().disableExtension(extension);
    }

    function enableExtension(address extension) external override onlyManager isProxyReady returns (bool) {
        return _getStorageContract().enableExtension(extension);
    }

    function allExtensions() external override view isProxyReady returns (address[] memory) {
        return _getStorageContract().allExtensions();
    }

    function contextAddressForExtension(address extension) external override view isProxyReady returns (address) {
        return _getStorageContract().contextAddressForExtension(extension);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external virtual payable isProxyReady {
        _forwardCurrentCall();
    }

    function _forwardCurrentCall() private returns (bool) {
        _forwardCall(_msgData());
    }

    function _forwardCall(bytes memory _calldata) private returns (bool) {
        address store = address(_getStorageContract());

        // Forward call to storage contract, appending the current _msgSender to the
        // end of the current calldata
        (bool success, bytes memory result) = store.call{gas: gasleft(), value: msg.value}(abi.encodePacked(_calldata, _msgSender()));

        if (!success) {
            revert(string(result));
        }

        return success;
    }
    
    receive() external payable {}
    
    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC721;
    }
}