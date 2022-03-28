pragma solidity ^0.8.0;

import {ExtensionBase} from "./ExtensionBase.sol";
import {IExtension, TransferData, TokenStandard} from "../interface/IExtension.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RolesBase} from "../roles/RolesBase.sol";
import {IERC20Proxy} from "../tokens/proxy/ERC20/IERC20Proxy.sol";
import {TokenRolesConstants} from "../roles/TokenRolesConstants.sol";
import {IToken} from "../tokens/IToken.sol";

abstract contract TokenExtension is TokenRolesConstants, IExtension, ExtensionBase, RolesBase {
    mapping(TokenStandard => bool) supportedTokenStandards;
    //Should only be modified inside the constructor
    bytes4[] private _exposedFuncSigs;
    mapping(bytes4 => bool) private _interfaceMap;
    bytes32[] private _requiredRoles;
    address private _deployer;
    uint256 private _version;
    string private _package;
    bytes32 private _packageHash;

    constructor() {
        _deployer = msg.sender;
        __update_package_hash();
    }

    function __update_package_hash() private {
        _packageHash = keccak256(abi.encodePacked(_deployer, _package));
    }

    function _setVersion(uint256 __version) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");

        _version = __version;
    }

    function _setPackageName(string memory package) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");

        _package = package;

        __update_package_hash();
    }
    
    function _supportsTokenStandard(TokenStandard tokenStandard) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        supportedTokenStandards[tokenStandard] = true;
    }

    function _supportsAllTokenStandards() internal {
        _supportsTokenStandard(TokenStandard.ERC20);
        _supportsTokenStandard(TokenStandard.ERC721);
        _supportsTokenStandard(TokenStandard.ERC1400);
        _supportsTokenStandard(TokenStandard.ERC1155);
    }

    function extensionDeployer() external override view returns (address) {
        return _deployer;
    }

    function packageHash() external override view returns (bytes32) {
        return _packageHash;
    }

    function version() external override view returns (uint256) {
        return _version;
    }

    function isTokenStandardSupported(TokenStandard standard) external override view returns (bool) {
        return supportedTokenStandards[standard];
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
        _requiredRoles.push(roleId);
    }

    function _supportInterface(bytes4 interfaceId) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _interfaceMap[interfaceId] = true;
    }

    function _registerFunctionName(string memory selector) internal {
        _registerFunction(bytes4(keccak256(abi.encodePacked(selector))));
    }

    function _registerFunction(bytes4 selector) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _exposedFuncSigs.push(selector);
    }

    
    function externalFunctions() external override view returns (bytes4[] memory) {
        return _exposedFuncSigs;
    }

    function requiredRoles() external override view returns (bytes32[] memory) {
        return _requiredRoles;
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
}