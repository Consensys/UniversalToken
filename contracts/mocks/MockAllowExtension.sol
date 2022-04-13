pragma solidity ^0.8.0;

import {AllowExtension} from "../extensions/allowblock/allow/AllowExtension.sol";

contract MockAllowExtension is AllowExtension {

    constructor() {
        _registerFunction(this.mockUpgradeTest.selector);
        _setVersion(2);
    }

    function mockUpgradeTest() external view onlyAllowlistedAdmin returns (string memory) {
        return "This upgrade worked";
    }
}