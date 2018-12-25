pragma solidity ^0.4.24;
import "../token/ERC20/ERC1400ERC20.sol";
import "./CertificateControllerMock.sol";

contract ERC1400ERC20Mock is ERC1400ERC20, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner
  )
    public
    ERC1400ERC20(name, symbol, granularity, controllers, certificateSigner)
  {}

}
