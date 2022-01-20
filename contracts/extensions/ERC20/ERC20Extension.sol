pragma solidity ^0.8.0;

import {IERC20Extension, TransferData} from "./IERC20Extension.sol";
import {Roles} from "../../roles/Roles.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ExtensionBase} from "../ExtensionBase.sol";
import {RolesBase} from "../../roles/RolesBase.sol";
import {IToken} from "../../tokens/IToken.sol";

abstract contract ERC20Extension is IERC20Extension, ExtensionBase, RolesBase {
    //Should only be modified inside the constructor
    bytes4[] private _exposedFuncSigs;
    mapping(bytes4 => bool) private _interfaceMap;
    bytes32[] private _requiredRoles;

    modifier onlyOwner {
        require(_msgSender() == _tokenOwner(), "Only the token owner can invoke");
        _;
    }

    modifier onlyTokenOrOwner {
        address msgSender = _msgSender();
        require(msgSender == _tokenOwner() || msgSender == _tokenAddress(), "Only the token or token owner can invoke");
        _;
    }

    function _requireRole(bytes32 roleId) internal {
        require(isInsideConstructorCall(), "Function must be called inside the constructor");
        _requiredRoles.push(roleId);
    }

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

    
    function externalFunctions() external override view returns (bytes4[] memory) {
        return _exposedFuncSigs;
    }

    function requiredRoles() external override view returns (bytes32[] memory) {
        return _requiredRoles;
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

    function _transfer(TransferData memory data) internal returns (bool) {
        IToken token = IToken(_tokenAddress());
        return token.transfer(data);
    }

    function _transfer(address recipient, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(_tokenAddress());
        return token.transfer(recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(_tokenAddress());
        return token.transferFrom(sender, recipient, amount);
    }

    function _approve(address spender, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(_tokenAddress());
        return token.approve(spender, amount);
    }

    function _allowance(address owner, address spender) internal view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress());
        return token.allowance(owner, spender);
    }
    
    function _balanceOf(address account) internal view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress());
        return token.balanceOf(account);
    }

    function _totalSupply() internal view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress());
        return token.totalSupply();
    }

    function _isTokenOwner(address addr) internal view returns (bool) {
        return addr == _tokenOwner();
    }

    function _tokenOwner() internal view returns (address) {
        Ownable token = Ownable(_tokenAddress());

        return token.owner();
    }
}