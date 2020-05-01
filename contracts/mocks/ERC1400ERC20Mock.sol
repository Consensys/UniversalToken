pragma solidity ^0.5.0;

import "../token/ERC20/ERC1400ERC20.sol";


contract ERC1400ERC20Mock is ERC1400ERC20 {

  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    address certificateSigner,
    bool certificateActivated,
    bytes32[] memory defaultPartitions
  )
    public
    ERC1400ERC20(name, symbol, granularity, controllers, certificateSigner, certificateActivated, defaultPartitions)
  {}

}
