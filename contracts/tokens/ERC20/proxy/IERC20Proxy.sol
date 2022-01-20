pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IToken} from "../../IToken.sol";
import {IERC20ProxyRoles} from "./IERC20ProxyRoles.sol";

interface IERC20Proxy is IERC20Metadata, IToken, IERC20ProxyRoles {
    function mintingAllowed() external view returns (bool);

    function burningAllowed() external view returns (bool);

    function domainName() external view returns (bytes memory);

    function domainVersion() external view returns (bytes32);

    function upgradeTo(address implementation) external;

    function registerExtension(address extension) external returns (bool);

    function removeExtension(address extension) external returns (bool);

    function disableExtension(address extension) external returns (bool);

    function enableExtension(address extension) external returns (bool);

    function allExtensions() external view returns (address[] memory);

    function mint(address to, uint256 amount) external returns (bool);

        /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) external returns (bool);

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
    function burnFrom(address account, uint256 amount) external returns (bool);

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
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

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
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function contextAddressForExtension(address extension) external view returns (address);
}