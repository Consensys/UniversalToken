pragma solidity ^0.8.0;

import {IERC20Extension, TransferData} from "./IERC20Extension.sol";
import {Roles} from "../../roles/Roles.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Core} from "../../tokens/ERC20/implementation/core/IERC20Core.sol";
import {ERC20ProxyStorage} from "../../tokens/ERC20/storage/ERC20ProxyStorage.sol";
import {ContextData} from "../ExtensionContext.sol";

abstract contract ERC20Extension is IERC20Extension, ERC20ProxyStorage {
    //Should only be modified inside the constructor
    bytes4[] private _exposedFuncSigs;
    mapping(bytes4 => bool) private _interfaceMap;

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

    function _currentTokenAddress() internal view returns (address) {
        ContextData storage ds;
        bytes32 position = CONTEXT_DATA_SLOT;
        assembly {
            ds.slot := position
        }

        return ds.token;
    }

    function _transfer(address recipient, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(_currentTokenAddress());
        return token.transfer(recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(_currentTokenAddress());
        return token.transferFrom(sender, recipient, amount);
    }

    function _approve(address spender, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(_currentTokenAddress());
        return token.approve(spender, amount);
    }

    function _allowance(address owner, address spender) internal view returns (uint256) {
        IERC20 token = IERC20(_currentTokenAddress());
        return token.allowance(owner, spender);
    }
    
    function _balanceOf(address account) internal view returns (uint256) {
        IERC20 token = IERC20(_currentTokenAddress());
        return token.balanceOf(account);
    }

    function _totalSupply() internal view returns (uint256) {
        IERC20 token = IERC20(_currentTokenAddress());
        return token.totalSupply();
    }

    function externalFunctions() external override view returns (bytes4[] memory) {
        return _exposedFuncSigs;
    }

    function isInsideConstructorCall() internal view returns (bool) {
        uint size;
        address addr = address(this);
        assembly { size := extcodesize(addr) }
        return size == 0;
    } 

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
        return interfaceId == type(IERC20Extension).interfaceId || interfaceId == type(IERC165).interfaceId || _interfaceMap[interfaceId];
    }
}