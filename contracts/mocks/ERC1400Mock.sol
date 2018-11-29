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

  function fakeAddDefaultOperatorByTranche(bytes32 tranche, address operator) external onlyOwner {
    _addDefaultOperatorByTranche(tranche, operator);
  }

}
