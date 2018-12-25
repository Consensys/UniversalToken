pragma solidity ^0.4.24;
import "../ERC1400.sol";
import "./CertificateControllerMock.sol";


contract ERC1400Mock is ERC1400, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner
  )
    public
    ERC1400(name, symbol, granularity, defaultOperators, certificateSigner)
  {
  }

  function fakeAddDefaultOperatorByPartition(bytes32 partition, address operator) external onlyOwner {
    _addDefaultOperatorByPartition(partition, operator);
  }

}
