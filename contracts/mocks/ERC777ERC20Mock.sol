pragma solidity ^0.4.24;
import "../token/ERC20/ERC777ERC20.sol";
import "./CertificateControllerMock.sol";


contract ERC777ERC20Mock is ERC777ERC20, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner
  )
    public
    ERC777ERC20(name, symbol, granularity, defaultOperators, certificateSigner)
  {
  }


}
