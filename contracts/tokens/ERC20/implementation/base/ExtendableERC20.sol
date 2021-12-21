pragma solidity ^0.8.0;

import {ERC20ExtendableBase} from "../../extensions/ERC20ExtendableBase.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Extension, TransferData} from "../../../../extensions/ERC20/IERC20Extension.sol";

contract ExtendableERC20 is ERC20, ERC20ExtendableBase, Ownable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

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
}