import "hardhat/console.sol";

contract EventManager {
    struct SavedCallbackFunction {
        function () external returns (bool) func;
    }

    mapping(bytes32 => SavedCallbackFunction[]) listeners;

    function on(bytes32 eventId, function () external returns (bool) callback) public {
        listeners[eventId].push(SavedCallbackFunction(callback));
    }

    function trigger(bytes32 eventId) public {
        SavedCallbackFunction[] storage callbacks = listeners[eventId];

        for (uint i = 0; i < callbacks.length; i++) {
            bool result = callbacks[i].func();

            require(result, "Bad response");
        }
    }
}

contract A is EventManager {
    bytes32 constant internal TRANFER_EVENT = keccak256("A.transfer");

    function transfer() external {
        trigger(TRANFER_EVENT);
    }
}

contract B {
    bytes32 constant internal TRANFER_EVENT = keccak256("A.transfer");

    constructor(A source) {
        source.on(TRANFER_EVENT, this.callback);
    }

    function callback() public returns (bool) {

    }
}

contract C {

}