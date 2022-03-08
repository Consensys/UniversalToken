pragma solidity ^0.8.0;

import {IToken, TokenStandard} from "../../../interface/IToken.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ExtendableHooks} from "../../extension/ExtendableHooks.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {TransferData} from "../../../extensions/IExtension.sol";
import {TokenRoles} from "../../../roles/TokenRoles.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {ITokenLogic} from "../../../interface/ITokenLogic.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

contract ERC20Logic is ERC20Upgradeable, ERC1820Client, ERC1820Implementer, ExtendableHooks, ITokenLogic {
    using BytesLib for bytes;

    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";

    bytes private _currentData;
    bytes private _currentOperatorData;

    constructor() {
        ERC1820Client.setInterfaceImplementation(ERC20_LOGIC_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_LOGIC_INTERFACE_NAME); // For migration
    }

    function initialize(bytes memory data) external override {
        require(msg.sender == _callsiteAddress(), "Unauthorized");
        require(_onInitialize(data), "Initialize failed");
    }

    function _onInitialize(bytes memory data) internal virtual returns (bool) {
        return true;
    }

    function _msgSender() internal view override(ContextUpgradeable, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, Context) returns (bytes memory) {
        return ContextUpgradeable._msgData();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override virtual {
        TransferData memory data = TransferData(
            _callsiteAddress(),
            _msgData(),
            0x00000000000000000000000000000000,
            _msgSender(),
            from,
            to,
            amount,
            0,
            _currentData,
            _currentOperatorData
        );
        
        _currentData = "";
        _currentOperatorData = "";

        _triggerTokenTransfer(data);
    }

    function _isMinter(address caller) internal view returns (bool) {
        address tokenProxy = _callsiteAddress();

        uint size;
        assembly { size := extcodesize(tokenProxy) }
        bool isTokenBeingConstructed = size == 0;

        if (isTokenBeingConstructed) {
            return true;
        }

        TokenRoles proxy = TokenRoles(tokenProxy);
        bool minter = proxy.isMinter(caller);
        return minter;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        require(_isMinter(_msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");

        _mint(to, amount);

        return true;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual returns (bool) {
        _burn(_msgSender(), amount);
        return true;
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
    function burnFrom(address account, uint256 amount) public virtual returns (bool) {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);

        return true;
    }

    function tokenTransfer(TransferData calldata td) external override returns (bool) {
        require(td.partition == bytes32(0), "Invalid transfer data: partition");
        require(td.token == _callsiteAddress(), "Invalid transfer data: token");
        require(td.tokenId == 0, "Invalid transfer data: tokenId");

        _currentData = td.data;
        _currentOperatorData = td.operatorData;
        _transfer(td.from, td.to, td.value);

        return true;
    }

    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC20;
    }

    // Override normal transfer functions
    // That way we can grab any extra data
    // that may be attached to the calldata
    // (not including the forwarded _msgSender() from proxy)
    
    uint256 private constant MSG_SENDER_SIZE = 20;
    uint256 private constant TRANSFER_CALL_SIZE = 20 + 32 + MSG_SENDER_SIZE;
    uint256 private constant TRANSFER_FROM_CALL_SIZE = 20 + 20 + 32 + MSG_SENDER_SIZE;
    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        bytes memory cdata = _msgData();

        if (cdata.length > TRANSFER_CALL_SIZE) {
            //Start the slice from where the normal 
            //parameter arguments should end
            uint256 start = TRANSFER_CALL_SIZE - MSG_SENDER_SIZE;

            //The size of the slice will be the difference
            //in expected size to actual size
            uint256 size = cdata.length - TRANSFER_CALL_SIZE;
            
            bytes memory extraData = cdata.slice(start, size);

            _currentData = extraData;
            _currentOperatorData = extraData;
        }
        
        return ERC20Upgradeable.transfer(recipient, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        bytes memory cdata = _msgData();

        if (cdata.length > TRANSFER_FROM_CALL_SIZE) {
            //Start the slice from where the normal 
            //parameter arguments should end
            uint256 start = TRANSFER_FROM_CALL_SIZE - MSG_SENDER_SIZE;

            //The size of the slice will be the difference
            //in expected size to actual size
            uint256 size = cdata.length - TRANSFER_FROM_CALL_SIZE;
            
            bytes memory extraData = cdata.slice(start, size);

            _currentData = extraData;
            _currentOperatorData = extraData;
        }

        return ERC20Upgradeable.transferFrom(sender, recipient, amount);
    }

    /**
    * This empty reserved space is put in place to allow future versions to add new
    * variables without shifting down storage in the inheritance chain.
    * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    */
    uint256[48] private __gap;
}