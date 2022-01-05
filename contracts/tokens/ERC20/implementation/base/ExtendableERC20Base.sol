pragma solidity ^0.8.0;

import {Diamond} from "../../../../tools/diamond/Diamond.sol";
import {ERC20ExtendableBase} from "../../extensions/ERC20ExtendableBase.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Extension, TransferData} from "../../../../extensions/ERC20/IERC20Extension.sol";
import {Roles} from "../../../../roles/Roles.sol";

contract ExtendableERC20Base is ERC20, ERC20ExtendableBase, Ownable, Diamond {
    using Roles for Roles.Role;

    bool public burningAllowed;
    bool public mintingAllowed;
    bytes32 constant ERC20_MINTER_ROLE = keccak256("erc20.proxy.core.mint.role");

    constructor(
        string memory name_, string memory symbol_,
        bool allowMint_, bool allowBurn_, address owner
    ) 
    ERC20(name_, symbol_) 
    Diamond(owner) 
    {
        burningAllowed = allowBurn_;
        mintingAllowed = allowMint_;

        transferOwnership(owner);
        
        if (mintingAllowed) {
            addMinter(owner);
        }
    }

    modifier onlyMinter {
        require(isMinter(_msgSender()), "This function can only be invoked by a minter");
        _;
    }

    modifier mintingEnabled {
        require(mintingAllowed, "Minting is disabled");
        _;
    }

    modifier burningEnabled {
        require(burningAllowed, "Burning is disabled");
        _;
    }

    function isMinter(address caller) public view returns (bool) {
        return hasRole(caller, ERC20_MINTER_ROLE);
    }

    function addMinter(address caller) public onlyMinter {
        _addRole(caller, ERC20_MINTER_ROLE);
    }

    function removeMinter(address caller) public onlyMinter {
        _removeRole(caller, ERC20_MINTER_ROLE);
    }

    function hasRole(address caller, bytes32 roleId) public view returns (bool) {
        return Roles.roleStorage(roleId).has(caller);
    }

    function _addRole(address caller, bytes32 roleId) internal {
        Roles.roleStorage(roleId).add(caller);
    }

    function _removeRole(address caller, bytes32 roleId) internal {
        Roles.roleStorage(roleId).remove(caller);
    }

    function registerExtension(address extension) public virtual onlyOwner returns (bool) {
        return _registerExtension(extension);
    }

    function removeExtension(address extension) public virtual onlyOwner returns (bool) {
        return _removeExtension(extension);
    }

    function disableExtension(address extension) external virtual onlyOwner returns (bool) {
        return _disableExtension(extension);
    }

    function enableExtension(address extension) external virtual onlyOwner returns (bool) {
        return _enableExtension(extension);
    }

    function allExtension() external view onlyOwner returns (address[] memory) {
        return _allExtension();
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

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external override payable {
        _callFunction(msg.sig);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual burningEnabled {
        _burn(_msgSender(), amount);
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
    function burnFrom(address account, uint256 amount) public virtual burningEnabled {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
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
    function mint(address to, uint256 amount) public virtual mintingEnabled onlyMinter {
        _mint(to, amount);
    }
}