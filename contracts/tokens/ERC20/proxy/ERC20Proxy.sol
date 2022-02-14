pragma solidity ^0.8.0;

import {IERC20Proxy} from "./IERC20Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {TokenRoles} from "../../roles/TokenRoles.sol";
import {DomainAware} from "../../../tools/DomainAware.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {IERC20Logic} from "../logic/IERC20Logic.sol";
import {ERC20Storage} from "../storage/ERC20Storage.sol";
import {ExtensionStorage} from "../../../extensions/ExtensionStorage.sol";
import {IToken, TransferData, TokenStandard} from "../../IToken.sol";

contract ERC20Proxy is IERC20Proxy, TokenRoles, DomainAware, ERC1820Client, ERC1820Implementer {
    string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
    string constant internal ERC20_STORAGE_INTERFACE_NAME = "ERC20TokenStorage";
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";
    bytes32 constant ERC20_TOKEN_META = keccak256("erc20.token.meta");

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
            _addRole(owner, TOKEN_MINTER_ROLE);
        }

        TokenMeta storage m = _getTokenMeta();
        m.name = name_;
        m.symbol = symbol_;
        m.maxSupply = maxSupply_;
        m.allowMint = allowMint;
        m.allowBurn = allowBurn;

        ERC1820Client.setInterfaceImplementation(ERC20_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_INTERFACE_NAME); // For migration

        require(logicAddress != address(0), "Logic address must be given");
        require(logicAddress == ERC1820Client.interfaceAddr(logicAddress, ERC20_LOGIC_INTERFACE_NAME), "Not registered as a logic contract");

        _setImplementation(logicAddress);

        ERC20Storage store = new ERC20Storage(address(this));

        _setStorage(address(store));

        //Update the doamin seperator now that 
        //we've setup everything
        _updateDomainSeparator();

        m.initialized = true;
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
        bytes32 slot = ERC20_TOKEN_META;
        assembly {
            r.slot := slot
        }
    }

    function _getStorageContract() internal view returns (IERC20Logic) {
        return IERC20Logic(
            ERC1820Client.interfaceAddr(address(this), ERC20_STORAGE_INTERFACE_NAME)
        );
    }

    function _getImplementationContract() internal view returns (address) {
        return ERC1820Client.interfaceAddr(address(this), ERC20_LOGIC_INTERFACE_NAME);
    }

    function _setImplementation(address implementation) internal {
        ERC1820Client.setInterfaceImplementation(ERC20_LOGIC_INTERFACE_NAME, implementation);
    }

    function _setStorage(address store) internal {
        ERC1820Client.setInterfaceImplementation(ERC20_STORAGE_INTERFACE_NAME, store);
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public override view returns (uint256) {
        return _getStorageContract().totalSupply();
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

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public override view returns (uint8) {
        return _getStorageContract().decimals();
    }

    function tokenTransfer(TransferData calldata td) external override onlyControllers returns (bool) {
        require(td.token == address(this), "Invalid token");

        if (td.partition != bytes32(0)) {
            return false; //We cannot do partition transfers
        }

        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(td.from, td.to, td.value);
        }

        return result;
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public override virtual onlyMinter mintingEnabled returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            TokenMeta storage m = _getTokenMeta();

            //Lets do a final maxSupply check here
            require(totalSupply() <= m.maxSupply, "ERC20: Max supply reached");

            emit Transfer(address(0), to, amount);
        }
        return result;
    }

        /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public override virtual burningEnabled returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(_msgSender(), address(0), amount);
        }
        return result;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public override virtual burningEnabled returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(account, address(0), amount);
        }
        return result;
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Transfer(_msgSender(), recipient, amount);
        }
        return result;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) public override view returns (uint256) {
        return _getStorageContract().allowance(owner, spender);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            emit Approval(_msgSender(), spender, amount);
        }
        return result;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        (bool result,) = _forwardCurrentCall();

        if (result) {
            emit Transfer(sender, recipient, amount);
            uint256 allowanceAmount = _getStorageContract().allowance(sender, _msgSender());
            emit Approval(sender, _msgSender(), allowanceAmount);
        }

        return result;
    }

    /** 
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public override virtual returns (bool) {
        (bool result,) = _forwardCurrentCall();

        if (result) {
            uint256 allowanceAmount = _getStorageContract().allowance(_msgSender(), spender);
            emit Approval(_msgSender(), spender, allowanceAmount);
        }
        return result;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public override virtual returns (bool) {
        (bool result,) = _forwardCurrentCall();
        if (result) {
            uint256 allowanceAmount = _getStorageContract().allowance(_msgSender(), spender);
            emit Approval(_msgSender(), spender, allowanceAmount);
        }
        return result;
    }

    function _transfer(TransferData memory td) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IToken.tokenTransfer.selector, td));
        return result;
    }

    function _mint(address receipient, uint256 amount) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20Proxy.mint.selector, receipient, amount));
        return result;
    }

    function _burn(uint256 amount) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20Proxy.burn.selector, amount));
        return result;
    }

    function _burnFrom(address receipient, uint256 amount) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20Proxy.burnFrom.selector, receipient, amount));
        return result;
    }

    function _decreaseAllowance(address spender, uint256 subtractedValue) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20Proxy.decreaseAllowance.selector, spender, subtractedValue));
        return result;
    }

    function _increaseAllowance(address spender, uint256 addedValue) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20Proxy.increaseAllowance.selector, spender, addedValue));
        return result;
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20.transferFrom.selector, sender, recipient, amount));
        return result;
    }

    function _approve(address spender, uint256 amount) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        return result;
    }

    function _transfer(address recipient, uint256 amount) internal returns (bool) {
        (bool result,) = _forwardCall(abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount));
        return result;
    }

    function domainName() public virtual override(DomainAware, IERC20Proxy) view returns (bytes memory) {
        return bytes(name());
    }

    function domainVersion() public virtual override(DomainAware, IERC20Proxy) view returns (bytes32) {
        return bytes32(uint256(uint160(address(_getImplementationContract()))));
    }

    function upgradeTo(address implementation, bytes memory data) external override onlyManager {
        _setImplementation(implementation);

        //Invoke initalize
        require(_getStorageContract().onUpgrade(data), "Logic initializing failed");
    }

    function registerExtension(address extension) external override onlyManager returns (bool) {
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

    function removeExtension(address extension) external override onlyManager returns (bool) {
       bool result = _getStorageContract().removeExtension(extension);

       if (result) {
            address contextAddress = _getStorageContract().contextAddressForExtension(extension);
            ExtensionStorage context = ExtensionStorage(payable(contextAddress));

            bytes32[] memory requiredRoles = context.requiredRoles();
            
            //If we have roles we need to register, then lets register them
            if (requiredRoles.length > 0) {
                address ctxAddress = address(context);
                for (uint i = 0; i < requiredRoles.length; i++) {
                    _removeRole(ctxAddress, requiredRoles[i]);
                }
            }
        }

        return result;
    }

    function disableExtension(address extension) external override onlyManager returns (bool) {
        return _getStorageContract().disableExtension(extension);
    }

    function enableExtension(address extension) external override onlyManager returns (bool) {
        return _getStorageContract().enableExtension(extension);
    }

    function allExtensions() external override view returns (address[] memory) {
        return _getStorageContract().allExtensions();
    }

    function contextAddressForExtension(address extension) external override view returns (address) {
        return _getStorageContract().contextAddressForExtension(extension);
    }

    function bytesToHex(bytes memory x) internal pure returns (string memory) {
        bytes memory f = new bytes(x.length * 2);
        bytes memory hexChars = bytes("0123456789ABCDEF");
        for (uint j = 0; j < x.length; j++) {
            uint v = uint(uint8(x[j] & 0xFF));
            f[j * 2] = hexChars[v >> uint256(4)];
            f[j * 2 + 1] = hexChars[v & 0x0F];
        }

        return string(f);
    }

    // Forward any function not found here to the storage
    // contract, appending _msgSender() to the end of the 
    // calldata provided and return any values
    fallback() external virtual payable {
        //we cant define a return value for fallback
        //therefore, we must do the call in in-line assembly
        //so we can use the return() opcode to return
        //dynamic data from the storage contract
        address store = address(_getStorageContract());
        bytes memory cdata = abi.encodePacked(_msgData(), _msgSender());
        uint256 value = msg.value;

        // Execute external function from storage using call and return any value.
        assembly {
            // execute function call
            let result := call(gas(), store, value, add(cdata, 0x20), mload(cdata), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    function _forwardCurrentCall() private returns (bool, bytes memory) {
        return _forwardCall(_msgData());
    }

    function _forwardCall(bytes memory _calldata) private returns (bool success, bytes memory result) {
        address store = address(_getStorageContract());

        // Forward call to storage contract, appending the current _msgSender to the
        // end of the current calldata
        (success, result) = store.call{gas: gasleft(), value: msg.value}(abi.encodePacked(_calldata, _msgSender()));

        if (!success) {
            revert(string(result));
        }
    }
    
    receive() external payable {}

    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC20;
    }
}