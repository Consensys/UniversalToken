pragma solidity ^0.8.0;

import {ERC20Logic} from "../tokens/logic/ERC20/ERC20Logic.sol";

contract ERC20LogicMock is ERC20Logic {
    string private test;

    function _onInitialize(bytes memory data) internal override returns (bool) {
        test = "This is a mock!";

        return true;
    }

    function isMock() public view returns (string memory) {
        return test;
    }

    /**
    * This empty reserved space is put in place to allow future versions to add new
    * variables without shifting down storage in the inheritance chain.
    * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    */
    uint256[50] private __gap;
}