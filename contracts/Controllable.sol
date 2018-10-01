pragma solidity ^0.4.24;

import "./Controller.sol";
import "./libs/ownership/Ownable.sol";

contract Controllable is Ownable {
    Controller controller;

    event ControllerSet(
        address indexed previousController,
        address indexed newController
    );

    constructor(
        Controller _controller
    ) 
        public
    {
        require(_controller != address(0), "Must provide valid address");
        controller = _controller;
    }

    modifier isValid() {
        require(controller.isValid(), "Invalid action");
        _;
    }

    function setController(
        Controller _controller
    )
        public
        onlyOwner
    {
        _setController(_controller);
    }

    function _setController(
        Controller _controller
    )
        internal
    {
        require(controller != _controller, "Must set a new controller");
        
        emit ControllerSet(controller, _controller);

        controller = _controller;
    }

}