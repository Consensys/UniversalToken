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
import {IExtensionStorage} from "../../extension/IExtensionStorage.sol";
import {ITokenProxy, TokenProxy} from "../../proxy/TokenProxy.sol";

contract ERC20Proxy is TokenProxy, IERC20Proxy {
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

        if (owner != address(0) && owner != _msgSender()) {
            transferOwnership(owner);
            StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = owner;
        } else {
            StorageSlot.getAddressSlot(TOKEN_MANAGER_ADDRESS).value = _msgSender();
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

    function __tokenStorageInterfaceName() internal virtual override pure returns (string memory) {
        return ERC20_STORAGE_INTERFACE_NAME;
    }

    function __tokenLogicInterfaceName() internal virtual override pure returns (string memory) {
        return ERC20_LOGIC_INTERFACE_NAME;
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
        return IERC20Logic(_getStorageContractAddress());
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

    function transferWithData(address recipient, uint256 amount, bytes calldata data) public returns (bool) {
        bytes memory cdata = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount, data);

        (bool result,) = _forwardCall(cdata);
        if (result) {
            emit Transfer(_msgSender(), recipient, amount);
        }

        return result;
    }
    
    function transferFromWithData(address sender, address recipient, uint256 amount, bytes calldata data) public returns (bool) {
        bytes memory cdata = abi.encodeWithSelector(IERC20.transferFrom.selector, sender, recipient, amount, data);

        (bool result,) = _forwardCall(cdata);
        if (result) {
            emit Transfer(_msgSender(), recipient, amount);
        }

        return result;
    }

    // has same function selector as transfer(address,uint256)
/*  function transferWithData_729714112(address recipient, uint256 amount, bytes calldata data) public returns (bool) {

    } */

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

    function _domainName() internal virtual override view returns (bytes memory) {
        return bytes(name());
    }

    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC20;
    }
}