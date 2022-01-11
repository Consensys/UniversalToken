pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC20ExtendableHooks} from "../../extensions/ERC20ExtendableHooks.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyContext} from "../../../../tools/context/ProxyContext.sol";
import {IERC20Extension, TransferData} from "../../../../extensions/ERC20/IERC20Extension.sol";
import {Roles} from "../../../../roles/Roles.sol";

contract ERC20Logic is ERC20, ERC20ExtendableHooks, ProxyContext {
    constructor() ERC20("", "") { }

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
}