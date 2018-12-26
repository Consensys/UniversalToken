pragma solidity ^0.4.24;
import "../ERC1400.sol";
import "./CertificateControllerMock.sol";


contract ERC1400Mock is ERC1400, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner,
    bytes32[] tokenDefaultPartitions
  )
    public
    ERC1400(name, symbol, granularity, controllers, certificateSigner, tokenDefaultPartitions)
  {
  }

  function fakeAddPartitionController(bytes32 partition, address operator) external onlyOwner {
    _addPartitionController(partition, operator);
  }

}
