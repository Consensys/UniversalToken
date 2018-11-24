pragma solidity ^0.4.24;
import "../token/ERC777/ERC777Mintable.sol";
import "./CertificateControllerMock.sol";


contract ERC777Mock is ERC777Mintable, CertificateControllerMock {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner
  )
    public
    ERC777(name, symbol, granularity, defaultOperators, certificateSigner)
  {
  }

  function addDefaultOperator(address operator) external onlyOwner {
    _addDefaultOperator(operator);
  }

  function removeDefaultOperator(address operator) external onlyOwner {
    _removeDefaultOperator(operator);
  }

  function isRegularAddress(address adr) external view returns(bool) {
    return _isRegularAddress(adr);
  }

  function operatorBurnMock(address from, uint256 amount, bytes data, bytes operatorData) external {
    _burn(msg.sender, from, amount, data, operatorData);
  }

}
