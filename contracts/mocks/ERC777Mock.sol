pragma solidity >=0.4.24;
import "../token/ERC777/ERC777Issuable.sol";


contract ERC777Mock is ERC777Issuable {

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner
  )
    public
    ERC777(name, symbol, granularity, controllers, certificateSigner)
  {
  }

  function setControllable(bool _controllable) external onlyOwner {
    _isControllable = _controllable;
  }

  function renounceControl() external onlyOwner {
    _isControllable = false;
  }

  function setControllers(address[] operators) external onlyOwner {
    _setControllers(operators);
  }

  function isRegularAddress(address adr) external view returns(bool) {
    return _isRegularAddress(adr);
  }

  function redeemFromMock(address from, uint256 value, bytes data, bytes operatorData) external {
    _redeem("", msg.sender, from, value, data, operatorData);
  }

}
