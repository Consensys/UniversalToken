pragma solidity ^0.8.0;

import {IERC20Proxy} from "./IERC20Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Logic} from "../../logic/ERC20/IERC20Logic.sol";
import {IToken, TransferData, TokenStandard} from "../../../interface/IToken.sol";
import {ExtendableTokenProxy} from "../ExtendableTokenProxy.sol";
import {ERC20TokenInterface} from "../../registry/ERC20TokenInterface.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

contract ERC20Proxy is ERC20TokenInterface, ExtendableTokenProxy, IERC20Proxy {
    using BytesLib for bytes;
    
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
    ) ExtendableTokenProxy(logicAddress, owner) { 
        require(maxSupply_ > 0, "Max supply must be non-zero");

        if (allowMint) {
            _addRole(owner, TOKEN_MINTER_ROLE);
        }

        TokenMeta storage m = _getTokenMeta();
        m.name = name_;
        m.symbol = symbol_;
        m.maxSupply = maxSupply_;
        m.allowMint = allowMint;
        m.allowBurn = allowBurn;

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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public override view returns (uint256) {
        (,bytes memory result) = _staticDelegateCall(abi.encodeWithSelector(this.totalSupply.selector));

        return result.toUint256(0);
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
        (,bytes memory result) = _staticDelegateCall(abi.encodeWithSelector(this.balanceOf.selector, account));

        return result.toUint256(0);
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
    function decimals() public override view staticdelegated returns (uint8) { }
 
    function tokenTransfer(TransferData calldata td) external override onlyControllers returns (bool) {
        require(td.token == address(this), "Invalid token");

        if (td.partition != bytes32(0)) {
            return false; //We cannot do partition transfers
        }

        _delegateCurrentCall();
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
    /// #if_succeeds {:msg "The caller is a minter"} isMinter(_msgSender())
    /// #if_succeeds {:msg "Minting is enabled"} mintingAllowed()
    /// #if_succeeds {:msg "The to address balance increases"} old(balanceOf(to)) + amount == balanceOf(to)
    /// #if_succeeds {:msg "The total supply has increases as expected"} old(totalSupply()) + amount == totalSupply()
    /// #if_succeeds {:msg "The total supply is not bigger than the max cap"} old(totalSupply()) + amount <= _getTokenMeta().maxSupply
    function mint(address to, uint256 amount) public override virtual onlyMinter mintingEnabled returns (bool) {
        (bool result, ) = _delegatecall(_msgData());
        
        TokenMeta storage m = _getTokenMeta();
        require(totalSupply() <= m.maxSupply, "ERC20: Max supply reached");
        return result;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    /// #if_succeeds {:msg "Burning is enabled"} burningAllowed()
    /// #if_succeeds {:msg "The to address has enough to burn"} old(balanceOf(_msgSender())) <= amount
    /// #if_succeeds {:msg "There's enough in total supply to burn"} old(totalSupply()) <= amount
    /// #if_succeeds {:msg "The to address balance decreased as expected"} old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender())
    /// #if_succeeds {:msg "The total supply has decreased as expected"} old(totalSupply()) - amount == totalSupply()
    function burn(uint256 amount) public override virtual burningEnabled delegated returns (bool) { }
    
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
    /// #if_succeeds {:msg "Burning is enabled"} burningAllowed()
    /// #if_succeeds {:msg "The to account has enough to burn"} old(balanceOf(account)) <= amount
    /// #if_succeeds {:msg "The operator is allowed to burn the amount"} old(allowance(account, _msgSender())) <= amount
    /// #if_succeeds {:msg "There's enough in total supply to burn"} old(totalSupply()) <= amount
    /// #if_succeeds {:msg "The to address balance decreased as expected"} old(balanceOf(account)) - amount == balanceOf(account)
    /// #if_succeeds {:msg "The total supply has decreased as expected"} old(totalSupply()) - amount == totalSupply()
    /// #if_succeeds {:msg "The operator's balance does not change"} old(balanceOf(_msgSender())) == balanceOf(_msgSender())
    function burnFrom(address account, uint256 amount) public override virtual burningEnabled delegated returns (bool) { }

    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(_msgSender()) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} _msgSender() != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } _msgSender() == recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    function transferWithData(address recipient, uint256 amount, bytes calldata data) public returns (bool) {
        bytes memory cdata = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount, data);

        (bool result,) = _delegatecall(cdata);

        return result;
    }
    
    function transferFromWithData(address sender, address recipient, uint256 amount, bytes calldata data) public returns (bool) {
        bytes memory cdata = abi.encodeWithSelector(IERC20.transferFrom.selector, sender, recipient, amount, data);

        (bool result,) = _delegatecall(cdata);

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
    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(_msgSender()) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} _msgSender() != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } _msgSender() == recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    function transfer(address recipient, uint256 amount) public override delegated returns (bool) { }

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
    /// #if_succeeds {:msg "The spender's balance doesnt change"} old(balanceOf(spender)) == balanceOf(spender);
    /// #if_succeeds {:msg "The owner's balance doesnt change"} old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The spender's allowance increases as expected"} old(allowance(_msgSender(), spender)) + amount == allowance(_msgSender(), spender);
    function approve(address spender, uint256 amount) public override delegated returns (bool) { }

    function allowance(address owner, address spender) public override view returns (uint256) {
        (,bytes memory result) = _staticDelegateCall(abi.encodeWithSelector(this.allowance.selector, owner, spender));

        return result.toUint256(0);
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
    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(sender) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The operator's balance doesnt change if its not the receiver"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} sender != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } sender == recipient ==> old(balanceOf(recipient) == balanceOf(recipient));
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override delegated returns (bool) { }

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
    function increaseAllowance(address spender, uint256 addedValue) public override virtual delegated returns (bool) { }

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
    function decreaseAllowance(address spender, uint256 subtractedValue) public override virtual delegated returns (bool) { }

    function _transfer(TransferData memory td) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IToken.tokenTransfer.selector, td));
        return result;
    }

    function _mint(address receipient, uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20Proxy.mint.selector, receipient, amount));
        return result;
    }

    function _burn(uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20Proxy.burn.selector, amount));
        return result;
    }

    function _burnFrom(address receipient, uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20Proxy.burnFrom.selector, receipient, amount));
        return result;
    }

    function _decreaseAllowance(address spender, uint256 subtractedValue) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20Proxy.decreaseAllowance.selector, spender, subtractedValue));
        return result;
    }

    function _increaseAllowance(address spender, uint256 addedValue) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20Proxy.increaseAllowance.selector, spender, addedValue));
        return result;
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20.transferFrom.selector, sender, recipient, amount));
        return result;
    }

    function _approve(address spender, uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        return result;
    }

    function _transfer(address recipient, uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount));
        return result;
    }

    function _domainName() internal virtual override view returns (bytes memory) {
        return bytes(name());
    }

    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC20;
    }
}