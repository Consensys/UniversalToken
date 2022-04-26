pragma solidity ^0.8.0;

import {ExtensionBase} from "./ExtensionBase.sol";
import {IExtension, TransferData, TokenStandard} from "../interface/IExtension.sol";
import {OwnableUpgradeable} from "@gnus.ai/contracts-upgradeable-diamond/access/OwnableUpgradeable.sol";
import {TokenRoles} from "../roles/TokenRoles.sol";
import {IERC20Proxy} from "../tokens/proxy/ERC20/IERC20Proxy.sol";
import {IToken} from "../tokens/IToken.sol";
import {TokenEventListener} from "../tokens/extension/TokenEventListener.sol";
import {RegisteredFunctionLookup} from "../tools/RegisteredFunctionLookup.sol";

abstract contract TokenExtension is TokenEventListener, RegisteredFunctionLookup, ExtensionBase, TokenRoles, IExtension {
    bytes32 constant EXT_DATA_SLOT = keccak256("consensys.contracts.token.ext.storage.meta");

    /**
    * @dev The Metadata associated with the Extension that identifies it on-chain and provides
    * information about the Extension. This information includes what function selectors it exposes,
    * what token roles are required for the extension, and extension metadata such as the version, deployer address
    * and package hash
    * This data should only be modified inside the constructor
    * @param _packageHash Hash of the package namespace for this Extension
    * @param _deployer The address that deployed this Extension
    * @param _version The version of this Extension
    * @param _package The unhashed version of the package namespace for this Extension
    * @param _interfaceMap A mapping of interface IDs this Extension implements
    * @param supportedTokenStandards A mapping of token standards this Extension supports
    */
    struct TokenExtensionData {
        bytes32 _packageHash;
        address _deployer;
        uint256 _version;
        string _package;
        string _interfaceLabel;
        mapping(bytes4 => bool) _interfaceMap;
        mapping(TokenStandard => bool) supportedTokenStandards;
    }

    constructor() {
        _extensionData()._deployer = msg.sender;
        __update_package_hash();
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

    function _supportInterface(bytes4 interfaceId) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _extensionData()._interfaceMap[interfaceId] = true;
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

    function _erc20Token() internal view returns (IERC20Proxy) {
        return IERC20Proxy(payable(this));
    }

    function _tokenStandard() internal view returns (TokenStandard) {
        //TODO Optimize this
        return IToken(address(this)).tokenStandard();
    }

    function _buildTransfer(address from, address to, uint256 amountOrTokenId) internal view returns (TransferData memory) {
        uint256 amount = amountOrTokenId;
        uint256 tokenId = 0;
        if (_tokenStandard() == TokenStandard.ERC721) {
            amount = 0;
            tokenId = amountOrTokenId;
        }

        address token = address(this);
        return TransferData(
            token,
            _msgData(),
            bytes32(0),
            _extensionAddress(),
            from,
            to,
            amount,
            tokenId,
            bytes(""),
            bytes("")
        );
    }

    function _buildTransferWithData(address from, address to, uint256 amountOrTokenId, bytes memory data) internal view returns (TransferData memory) {
        TransferData memory t = _buildTransfer(from, to, amountOrTokenId);
        t.data = data;
        return t;
    }

    function _buildTransferWithOperatorData(address from, address to, uint256 amountOrTokenId, bytes memory data) internal view returns (TransferData memory) {
        TransferData memory t = _buildTransfer(from, to, amountOrTokenId);
        t.operatorData = data;
        return t;
    }

    function _tokenTransfer(TransferData memory tdata) internal returns (bool) {
        return IToken(address(this)).tokenTransfer(tdata);
    }

    function _listenForTokenTransfers(function (TransferData memory) external returns (bool) callback) internal {
        _on(TOKEN_TRANSFER_EVENT, _extensionAddress(), callback.selector);
    }

    function _listenForTokenBeforeTransfers(function (TransferData memory) external returns (bool) callback) internal {
        _on(TOKEN_BEFORE_TRANSFER_EVENT, _extensionAddress(), callback.selector);
    }

    function _listenForTokenApprovals(function (TransferData memory) external returns (bool) callback) internal {
        _on(TOKEN_APPROVE_EVENT, _extensionAddress(), callback.selector);
    }
}