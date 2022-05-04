pragma solidity ^0.8.0;

import {BlockExtension} from "../../extensions/allowblock/block/BlockExtension.sol";

contract MockBlockExtension is BlockExtension {

    constructor() {
        _registerFunction(this.mockUpgradeTest.selector);
        _setVersion(2);
    }

    function mockUpgradeTest() external view onlyBlocklistedAdmin returns (string memory) {
        return "This upgrade worked";
    }
}