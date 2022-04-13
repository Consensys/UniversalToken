pragma solidity ^0.8.0;

import {TokenExtension, TransferData} from "../TokenExtension.sol";
import {TokenEventManager} from "../../tokens/extension/TokenEventManager.sol";
import {IHelloWorldExtension} from "./IHelloWorldExtension.sol";

contract HelloWorldExtension is TokenExtension, TokenEventManager, IHelloWorldExtension {

    /**
    * @dev Defines the storage slot for this Token Extension. This should the hash
    * of a unique package string. The storage slot should not overlap or conflict with
    * any existing storage slot in the TokenProxy or in any other Token Extension
    */
    bytes32 constant HELLO_WORLD_SLOT = keccak256("com.edkek.unique.example");

    /**
    * @dev The storage structure for this Token Extension. Defines a simple
    * counter as an example
    */
    struct HelloWorldState {
        uint counter;
    }

    /**
    * @dev A function to get the current storage state storeed in the current Extension instance.
    */
    function _state() internal pure returns (HelloWorldState storage ds) {
        bytes32 position = HELLO_WORLD_SLOT;
        assembly {
            ds.slot := position
        }
    }

    constructor() {
        _registerFunction(this.resetCounter.selector);
        _registerFunction(this.viewTransactionCount.selector);
        
        //Also valid
        //_registerFunctionName('viewTransactionCount()');

        _supportInterface(type(IHelloWorldExtension).interfaceId);

        _supportsAllTokenStandards();

        _setPackageName("net.consensys.tokenext.HelloWorldExtension");
        _setVersion(1);
        _setInterfaceLabel("HelloWorldExtension");
    }

    function initialize() external override initializer {
        _listenForTokenTransfers(this.onTokenTransfer);
        _listenForTokenApprovals(this.onTokenTransfer);
    }

    function onTokenTransfer(TransferData memory data) external eventGuard returns (bool) {
        _state().counter++;

        if (_state().counter % 10 == 0) {
            //Trigger the counter.event token event
            _trigger(keccak256("counter.event"), data);
        }

        return true;
    }

    function resetCounter() external override onlyOwner {
        _state().counter = 0;
    }

    function viewTransactionCount() external override view returns (uint256) {
        return _state().counter;
    }
}