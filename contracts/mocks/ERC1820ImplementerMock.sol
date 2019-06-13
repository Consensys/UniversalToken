pragma solidity ^0.5.0;


contract ERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
    function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address);
    function setManager(address _addr, address _newManager) external;
    function getManager(address _addr) public view returns(address);
}


contract ERC1820ImplementerMock {
  bytes32 constant ERC1820_ACCEPT_MAGIC = keccak256(abi.encodePacked("ERC1820_ACCEPT_MAGIC"));

  ERC1820Registry constant ERC1820REGISTRY = ERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  bytes32 internal _interfaceHash;

  constructor(string memory interfaceLabel) public {
    _interfaceHash = keccak256(abi.encodePacked(interfaceLabel));
  }

  function setERC1820Implementer() external {
    require(ERC1820REGISTRY.getManager(msg.sender) == address(this), "Manager rights neeed to be transferred to this contract first.");
    ERC1820REGISTRY.setInterfaceImplementer(msg.sender, _interfaceHash, address(this));
    ERC1820REGISTRY.setManager(msg.sender, msg.sender);
  }

  function canImplementInterfaceForAddress(bytes32 interfaceHash, address /*addr*/) // Comments to avoid compilation warnings for unused variables.
    external
    view
    returns(bytes32)
  {
    if(interfaceHash == _interfaceHash) {
      return ERC1820_ACCEPT_MAGIC;
    } else {
      return "";
    }
  }

}
