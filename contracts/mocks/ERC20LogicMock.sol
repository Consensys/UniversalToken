pragma solidity ^0.8.0;

import {ERC20Logic} from "../tokens/logic/ERC20/ERC20Logic.sol";

contract ERC20LogicMock is ERC20Logic {
    bytes32 constant MOCK_DATA_SLOT = keccak256("consensys.contracts.token.storage.mock.state");

    struct MockData {
        string test;
    }

    /**
    * @dev The ProxyData struct stored in this registered Extension instance.
    */
    function _mockState() internal pure returns (MockData storage ds) {
        bytes32 position = MOCK_DATA_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function _onInitialize(bytes memory data) internal override returns (bool) {
        _mockState().test = "This is a mock!";

        return true;
    }

    function isMock() public view returns (string memory) {
        return _mockState().test;
    }

    /**
    * This empty reserved space is put in place to allow future versions to add new
    * variables without shifting down storage in the inheritance chain.
    * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    */
    uint256[50] private __gap;
}