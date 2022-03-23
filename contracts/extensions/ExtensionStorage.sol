pragma solidity ^0.8.0;

import {IToken} from "../tokens/IToken.sol";
import {IExtensionStorage} from "../interface/IExtensionStorage.sol";
import {IExtension} from "../interface/IExtension.sol";
import {IExtensionMetadata, TokenStandard} from "../interface/IExtensionMetadata.sol";
import {ExtensionBase} from "./ExtensionBase.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ExtensionStorage is IExtensionStorage, IExtensionMetadata, ExtensionBase {
    event ExtensionUpgraded(address indexed extension, address indexed newExtension);

    constructor(address token, address extension, address callsite) {
        //Setup proxy data
        ProxyData storage ds = _proxyData();

        ds.token = token;
        ds.extension = extension;
        ds.callsite = callsite;
        
        //Ensure we support this token standard
        TokenStandard standard = IToken(token).tokenStandard();

        require(isTokenStandardSupported(standard), "Extension does not support token standard");
        
        //Update EIP1967 Storage Slot
        bytes32 EIP1967_LOCATION = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
        StorageSlot.getAddressSlot(EIP1967_LOCATION).value = extension;
    }

    function _extension() internal view returns (IExtension) {
        ProxyData storage ds = _proxyData();
        return IExtension(ds.extension);
    }

    function upgradeTo(address extensionImplementation) external onlyAuthorizedCaller {
        IExtension ext = IExtension(extensionImplementation);

        address currentDeployer = extensionDeployer();
        address newDeployer = ext.extensionDeployer();

        require(currentDeployer == newDeployer, "Deployer address for new extension is different than current");

        bytes32 currentPackageHash = packageHash();
        bytes32 newPackageHash = ext.packageHash();

        require(currentPackageHash == newPackageHash, "Package for new extension is different than current");

        uint256 currentVersion = version();
        uint256 newVersion = ext.version();

        require(currentVersion != newVersion, "Versions should not match");

        //TODO Check interfaces?

        //Ensure we support this token standard
        ProxyData storage ds = _proxyData();
        TokenStandard standard = IToken(ds.token).tokenStandard();

        require(ext.isTokenStandardSupported(standard), "Token standard is not supported in new extension");

        address old = ds.extension;
        ds.extension = extensionImplementation;

        //Update EIP1967 Storage Slot
        bytes32 EIP1967_LOCATION = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
        StorageSlot.getAddressSlot(EIP1967_LOCATION).value = extensionImplementation;

        emit ExtensionUpgraded(old, extensionImplementation);
    }

    function prepareCall(address caller) external override onlyAuthorizedCaller {
        StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value = caller;
    }

    fallback() external payable {
        if (msg.sender != _authorizedCaller() && msg.sender != address(this)) {
            require(msg.sig != IExtension.initialize.selector, "Cannot directly invoke initialize");
            require(msg.sig != IExtension.onTransferExecuted.selector, "Cannot directly invoke transferExecuted");
            require(msg.sig != IExtensionStorage.prepareCall.selector, "Cannot directly invoke prepareCall");

            //They are calling the proxy directly
            //allow this, but just make sure we update the msg sender slot ourselves
            StorageSlot.getAddressSlot(MSG_SENDER_SLOT).value = msg.sender;
        }
        
        ProxyData storage ds = _proxyData();
        
        _delegate(ds.extension);
    }

    function initialize() external onlyAuthorizedCaller {
        ProxyData storage ds = _proxyData();

        ds.initialized = true;

        //now forward initalization to the extension
        _delegate(ds.extension);
    }

    /**
    * @dev Delegates execution to an implementation contract.
    * This is a low level function that doesn't return to its internal call site.
    * It will return to the external caller whatever the implementation returns.
    * @param implementation Address to delegate.
    */
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function externalFunctions() external override view returns (bytes4[] memory) {
        return _extension().externalFunctions();
    }

    function requiredRoles() external override view returns (bytes32[] memory) {
        return _extension().requiredRoles();
    }

    function isTokenStandardSupported(TokenStandard standard) public override view returns (bool) {
        return _extension().isTokenStandardSupported(standard);
    }

    function extensionDeployer() public view override returns (address) {
        return _extension().extensionDeployer();
    }

    function packageHash() public view override returns (bytes32) {
        return _extension().packageHash();
    }

    function version() public view override returns (uint256) {
        return _extension().version();
    }
}