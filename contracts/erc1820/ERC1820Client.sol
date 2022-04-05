
pragma solidity ^0.8.0;

import "@gnus.ai/contracts-upgradeable-diamond/utils/introspection/IERC1820RegistryUpgradeable.sol";


/// Base client to interact with the registry.
contract ERC1820Client {
    IERC1820RegistryUpgradeable constant ERC1820REGISTRY = IERC1820RegistryUpgradeable(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    function setInterfaceImplementation(string memory _interfaceLabel, address _implementation) internal {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        ERC1820REGISTRY.setInterfaceImplementer(address(this), interfaceHash, _implementation);
    }

    function interfaceAddr(address addr, string memory _interfaceLabel) internal view returns(address) {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        return ERC1820REGISTRY.getInterfaceImplementer(addr, interfaceHash);
    }

    function delegateManagement(address _newManager) internal {
        ERC1820REGISTRY.setManager(address(this), _newManager);
    }
}