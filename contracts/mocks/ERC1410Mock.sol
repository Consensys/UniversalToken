pragma solidity ^0.4.24;
import "../token/ERC1410/ERC1410.sol";
import "./CertificateControllerMock.sol";


contract ERC1410Mock is ERC1410, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner,
    address tokenHolderMock,
    uint256 valueMock
  )
    public
    ERC1410(name, symbol, granularity, controllers, certificateSigner)
  {
    _mint(msg.sender, tokenHolderMock, valueMock, "", "");
  }

}
