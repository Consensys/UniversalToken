pragma solidity ^0.8.0;

interface IExtendable {
    function registerExtension(address extension) external returns (bool);

    function removeExtension(address extension) external returns (bool);

    function disableExtension(address extension) external returns (bool);

    function enableExtension(address extension) external returns (bool);

    function allExtensions() external view returns (address[] memory);

    function contextAddressForExtension(address extension) external view returns (address);
}