pragma solidity ^0.4.24;
import "../ERC1400.sol";
import "./CertificateControllerMock.sol";


contract ERC1400Mock is ERC1400, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner
  )
    public
    ERC1400(name, symbol, granularity, controllers, certificateSigner)
  {
  }

  function fakeAddControllerByPartition(bytes32 partition, address operator) external onlyOwner {
    _addControllerByPartition(partition, operator);
  }

}
