pragma solidity ^0.8.0;

import {ExtensionBase} from "./ExtensionBase.sol";
import {IExtension, TransferData, TokenStandard} from "../interface/IExtension.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RolesBase} from "../roles/RolesBase.sol";
import {IERC20Proxy} from "../tokens/proxy/ERC20/IERC20Proxy.sol";
import {TokenRolesConstants} from "../roles/TokenRolesConstants.sol";
import {IToken} from "../tokens/IToken.sol";
import {ITokenEventManager} from "../interface/ITokenEventManager.sol";
import {TokenEventConstants} from "../tokens/extension/TokenEventConstants.sol";

abstract contract TokenExtension is TokenRolesConstants, TokenEventConstants, IExtension, ExtensionBase, RolesBase {
    bytes32 constant EXT_DATA_SLOT = keccak256("ext.meta.data");

    /**
    * @dev The Metadata associated with the Extension that identifies it on-chain and provides
    * information about the Extension. This information includes what function selectors it exposes,
    * what token roles are required for the extension, and extension metadata such as the version, deployer address
    * and package hash
    * This data should only be modified inside the constructor
    * @param _packageHash Hash of the package namespace for this Extension
    * @param _requiredRoles An array of token role IDs that are required for this Extension's registration
    * @param _deployer The address that deployed this Extension
    * @param _version The version of this Extension
    * @param _exposedFuncSigs An array of function selectors this Extension exposes to a Proxy or Diamond
    * @param _package The unhashed version of the package namespace for this Extension
    * @param _interfaceMap A mapping of interface IDs this Extension implements
    * @param supportedTokenStandards A mapping of token standards this Extension supports
    */
    struct TokenExtensionData {
        bytes32 _packageHash;
        bytes32[] _requiredRoles;
        address _deployer;
        uint256 _version;
        bytes4[] _exposedFuncSigs;
        string _package;
        string _interfaceLabel;
        mapping(bytes4 => bool) _interfaceMap;
        mapping(TokenStandard => bool) supportedTokenStandards;
    }

    constructor() {
        _extensionData()._deployer = msg.sender;
        __update_package_hash();

        require(bytes(_extensionData()._interfaceLabel).length > 0, "No interface label set in Extension constructor");
        require(_extensionData()._packageHash != bytes32(0), "No package set in Extension constructor");
    }

    /**
    * @dev The ProxyData struct stored in this registered Extension instance.
    */
    function _extensionData() internal pure returns (TokenExtensionData storage ds) {
        bytes32 position = EXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function __update_package_hash() private {
        TokenExtensionData storage data = _extensionData();
        data._packageHash = keccak256(abi.encodePacked(data._deployer, data._package));
    }

    function _setVersion(uint256 __version) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");

        _extensionData()._version = __version;
    }

    function _setInterfaceLabel(string memory interfaceLabel_) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");

        _extensionData()._interfaceLabel = interfaceLabel_;
    }

    function _setPackageName(string memory package) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");

        _extensionData()._package = package;

        __update_package_hash();
    }
    
    function _supportsTokenStandard(TokenStandard tokenStandard) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _extensionData().supportedTokenStandards[tokenStandard] = true;
    }

    function _supportsAllTokenStandards() internal {
        _supportsTokenStandard(TokenStandard.ERC20);
        _supportsTokenStandard(TokenStandard.ERC721);
        _supportsTokenStandard(TokenStandard.ERC1400);
        _supportsTokenStandard(TokenStandard.ERC1155);
    }

    function extensionDeployer() external override view returns (address) {
        return _extensionData()._deployer;
    }

    function packageHash() external override view returns (bytes32) {
        return _extensionData()._packageHash;
    }

    function version() external override view returns (uint256) {
        return _extensionData()._version;
    }

    function isTokenStandardSupported(TokenStandard standard) external override view returns (bool) {
        return _extensionData().supportedTokenStandards[standard];
    }

    modifier onlyOwner {
        require(_msgSender() == _tokenOwner(), "Only the token owner can invoke");
        _;
    }

    modifier onlyTokenOrOwner {
        address msgSender = _msgSender();
        require(msgSender == _tokenOwner() || msgSender == _tokenAddress(), "Only the token or token owner can invoke");
        _;
    }

    function _requireRole(bytes32 roleId) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _extensionData()._requiredRoles.push(roleId);
    }

    function _supportInterface(bytes4 interfaceId) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _extensionData()._interfaceMap[interfaceId] = true;
    }

    function _registerFunctionName(string memory selector) internal {
        _registerFunction(bytes4(keccak256(abi.encodePacked(selector))));
    }

    function _registerFunction(bytes4 selector) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _extensionData()._exposedFuncSigs.push(selector);
    }

    
    function externalFunctions() external override view returns (bytes4[] memory) {
        return _extensionData()._exposedFuncSigs;
    }

    function requiredRoles() external override view returns (bytes32[] memory) {
        return _extensionData()._requiredRoles;
    }

    /**
    * @notice The ERC1820 interface label the extension will be registered as in the ERC1820 registry
    */
    function interfaceLabel() external override view returns (string memory) {
        return _extensionData()._interfaceLabel;
    }

    function isInsideConstructorCall() internal view returns (bool) {
        uint size;
        address addr = address(this);
        assembly { size := extcodesize(addr) }
        return size == 0;
    }

    function _isTokenOwner(address addr) internal view returns (bool) {
        return addr == _tokenOwner();
    }

    function _erc20Token() internal view returns (IERC20Proxy) {
        return IERC20Proxy(_tokenAddress());
    }

    function _tokenOwner() internal view returns (address) {
        Ownable token = Ownable(_tokenAddress());

        return token.owner();
    }

    function _tokenStandard() internal view returns (TokenStandard) {
        return _proxyData().standard;
    }

    function _buildTransfer(address from, address to, uint256 amountOrTokenId) internal view returns (TransferData memory) {
        uint256 amount = amountOrTokenId;
        uint256 tokenId = 0;
        if (_tokenStandard() == TokenStandard.ERC721) {
            amount = 0;
            tokenId = amountOrTokenId;
        }

        address token = _tokenAddress();
        return TransferData(
            token,
            _msgData(),
            bytes32(0),
            address(this),
            from,
            to,
            amount,
            tokenId,
            bytes(""),
            bytes("")
        );
    }

    function _tokenTransfer(TransferData memory tdata) internal returns (bool) {
        return IToken(_tokenAddress()).tokenTransfer(tdata);
    }

    function _listenForTokenTransfers(function (TransferData memory) external returns (bool) callback) internal {
        ITokenEventManager eventManager = ITokenEventManager(_tokenAddress());

        eventManager.on(TOKEN_TRANSFER_EVENT, callback);
    }

    function _listenForTokenApprovals(function (TransferData memory) external returns (bool) callback) internal {
        ITokenEventManager eventManager = ITokenEventManager(_tokenAddress());

        eventManager.on(TOKEN_APPROVE_EVENT, callback);
    }
}