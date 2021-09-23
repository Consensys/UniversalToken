pragma solidity ^0.8.0;

import {ERC20Proxy} from "./ERC20Proxy.sol";
import {IERC20Core} from "../core/IERC20Core.sol";

contract ERC20DelegateProxy is ERC20Proxy {

    function _invokeCore(bytes memory _calldata) internal returns (bytes memory) {
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

    function _executeDecreaseAllowance(address caller, address spender, uint256 subtractedValue) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Core.decreaseAllowance.selector, caller, spender, subtractedValue))[0] == 0x01;
    }

    function _executeIncreaseAllowance(address caller, address spender, uint256 addedValue) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Core.increaseAllowance.selector, caller, spender, addedValue))[0] == 0x01;
    }

    function _executeTransferFrom(address caller, address sender, address recipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Core.transferFrom.selector, caller, sender, recipient, amount))[0] == 0x01;
    }

    function _executeApprove(address caller, address spender, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Core.approve.selector, caller, spender, amount))[0] == 0x01;
    }

    function _executeTransfer(address caller, address recipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Core.transfer.selector, caller, recipient, amount))[0] == 0x01;
    }
}