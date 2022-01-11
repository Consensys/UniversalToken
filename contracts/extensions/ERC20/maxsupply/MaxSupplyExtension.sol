pragma solidity ^0.8.0;

import {ERC20Extension} from "../ERC20Extension.sol";
import {IERC20Extension, TransferData} from "../IERC20Extension.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MaxSupplyExtension is ERC20Extension {

    uint256 private _maxSupply;

    constructor() {
        _registerFunction(MaxSupplyExtension.setMaxSupply.selector);
    }

    function initalize() external override {
    }

    function setMaxSupply(uint256 maxSupply) external onlyTokenOrOwner {
        _maxSupply = maxSupply;
    }

    function validateTransfer(TransferData memory data) external override view returns (bool) {
        bool isValid = data.from != address(0) || data.value + _totalSupply() <= _maxSupply;

        require(isValid, "Max cap reached");

        return isValid;
    }

    function onTransferExecuted(TransferData memory data) external override returns (bool) {
        return true;
    }
}