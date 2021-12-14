pragma solidity ^0.8.0;

interface IPausable {
    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);
    event Paused(address account);
    event Unpaused(address account);

    function isPaused() external view returns (bool);

    function pause() external;

    function unpause() external;

    function addPauser(address account) external;

    function removePauser(address account) external;

    function renouncePauser() external;
}