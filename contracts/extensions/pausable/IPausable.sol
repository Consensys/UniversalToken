pragma solidity ^0.8.0;

interface IPausable {
    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);
    event Paused(address indexed pauser);
    event Unpaused(address indexed pauser);
    event PausedFor(address indexed pauser, address indexed account);
    event UnpausedFor(address indexed pauser, address indexed account);

    function isPaused() external view returns (bool);

    function pause() external;

    function unpause() external;

    function addPauser(address account) external;

    function removePauser(address account) external;

    function renouncePauser() external;

    function isPausedFor(address caller) external view returns (bool);

    function pauseFor(address caller) external;

    function unpauseFor(address caller) external;

    function isPauser(address caller) external view returns (bool);
}