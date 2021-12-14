pragma solidity ^0.8.0;

import {IERC20Extension, TransferData} from "../IERC20Extension.sol";
import {Roles} from "../../roles/Roles.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Core} from "../../tokens/ERC20/implementation/core/IERC20Core.sol";
import {ERC20ProxyStorage} from "../../tokens/ERC20/storage/ERC20ProxyStorage.sol";

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

    function _getImplementationContract() private view returns (IERC20Core) {
        return IERC20Core(
            StorageSlot.getAddressSlot(ERC20_CORE_ADDRESS).value
        );
    }

    function _invokeCore(bytes memory _calldata) private returns (bytes memory) {
        address erc20Core = address(_getImplementationContract());
        (bool success, bytes memory data) = erc20Core.delegatecall(_calldata);
        if (!success) {
            if (data.length > 0) {
                // bubble up the error
                revert(string(data));
            } else {
                revert("TokenExtensionFacet: delegatecall to ERC20Core reverted");
            }
        }

        return data;
    }

    function _transfer(address from, address recipient, uint256 amount) internal returns (bool) {
        TransferData memory data = TransferData(
            address(this),
            msg.data,
            0x00000000000000000000000000000000,
            address(this), //TODO who is the operator?
            from,
            recipient,
            amount,
            "",
            ""
        );

        return _transfer(data);
    }

    function _transfer(TransferData memory data) internal returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Core.customTransfer.selector, data))[0] == 0x01;
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