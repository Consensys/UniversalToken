pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC20ExtendableHooks} from "../../extensions/ERC20ExtendableHooks.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyContext} from "../../../../tools/context/ProxyContext.sol";
import {TransferData} from "../../../../extensions/ERC20/IERC20Extension.sol";
import {ERC20ProxyRoles} from "../../proxy/ERC20ProxyRoles.sol";
import {ERC1820Client} from "../../../../tools/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../../interface/ERC1820Implementer.sol";

contract ERC20Logic is ERC20, ERC1820Client, ERC1820Implementer, ERC20ExtendableHooks, ProxyContext {
    string constant internal ERC20_LOGIC_INTERFACE_NAME = "ERC20TokenLogic";
    
    constructor() ERC20("", "") {
        ERC1820Client.setInterfaceImplementation(ERC20_LOGIC_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC20_LOGIC_INTERFACE_NAME); // For migration
     }

    function _msgSender() internal view override(Context, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override virtual {
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            _msgSender(),
            from,
            to,
            amount,
            "",
            ""
        );

        _triggerBeforeTokenTransfer(data);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override virtual {
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            _msgSender(),
            from,
            to,
            amount,
            "",
            ""
        );

        _triggerAfterTokenTransfer(data);
    }

    function _isMinter(address caller) internal view returns (bool) {
        address tokenProxy = _callsiteAddress();
        ERC20ProxyRoles proxy = ERC20ProxyRoles(tokenProxy);

        return proxy.isMinter(caller);
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
}