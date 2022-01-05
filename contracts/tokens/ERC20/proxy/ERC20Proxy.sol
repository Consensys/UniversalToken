pragma solidity ^0.8.0;

import {ERC20ProxyBase} from "./ERC20ProxyBase.sol";
import {IERC20Logic} from "../implementation/logic/IERC20Logic.sol";

abstract contract ERC20Proxy is ERC20ProxyBase {

    constructor(bool allowMint, bool allowBurn, address owner) ERC20ProxyBase(allowMint, allowBurn, owner) { }

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
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.decreaseAllowance.selector, caller, spender, subtractedValue))[0] == 0x01;
    }

    function _executeIncreaseAllowance(address caller, address spender, uint256 addedValue) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.increaseAllowance.selector, caller, spender, addedValue))[0] == 0x01;
    }

    function _executeTransferFrom(address caller, address sender, address recipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.transferFrom.selector, caller, sender, recipient, amount))[0] == 0x01;
    }

    function _executeApprove(address caller, address spender, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.approve.selector, caller, spender, amount))[0] == 0x01;
    }

    function _executeTransfer(address caller, address recipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.transfer.selector, caller, recipient, amount))[0] == 0x01;
    }

    function _executeMint(address caller, address recipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.mint.selector, caller, recipient, amount))[0] == 0x01; 
    }

    function _executeBurn(address caller, address receipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.burn.selector, caller, receipient, amount))[0] == 0x01;
    }

    function _executeBurnFrom(address caller, address receipient, uint256 amount) internal override returns (bool) {
        return _invokeCore(abi.encodeWithSelector(IERC20Logic.burnFrom.selector, caller, receipient, amount))[0] == 0x01;
    }
}