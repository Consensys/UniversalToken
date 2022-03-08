pragma solidity ^0.8.0;

import {IERC20Proxy} from "../../tokens/proxy/ERC20/IERC20Proxy.sol";
import {TokenExtension, TransferData} from "../TokenExtension.sol";

abstract contract ERC20Extension is TokenExtension {

    function _transfer(TransferData memory data) internal returns (bool) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.tokenTransfer(data);
    }

    function _transfer(address recipient, uint256 amount) internal returns (bool) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.transfer(recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.transferFrom(sender, recipient, amount);
    }

    function _approve(address spender, uint256 amount) internal returns (bool) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.approve(spender, amount);
    }

    function _allowance(address owner, address spender) internal view returns (uint256) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.allowance(owner, spender);
    }
    
    function _balanceOf(address account) internal view returns (uint256) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.balanceOf(account);
    }

    function _totalSupply() internal view returns (uint256) {
        IERC20Proxy token = IERC20Proxy(_tokenAddress());
        return token.totalSupply();
    }
}