pragma solidity ^0.5.0;
import "../token/ERC1400Raw/ERC1400RawIssuable.sol";


contract ERC1400RawMock is ERC1400RawIssuable {

  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    address certificateSigner
  )
    public
    ERC1400Raw(name, symbol, granularity, controllers, certificateSigner)
  {
  }

  function setControllable(bool _controllable) external onlyOwner {
    _isControllable = _controllable;
  }

  function renounceControl() external onlyOwner {
    _isControllable = false;
  }

  function setControllers(address[] calldata operators) external onlyOwner {
    _setControllers(operators);
  }

  function isRegularAddress(address adr) external view returns(bool) {
    return _isRegularAddress(adr);
  }

  function redeemFromMock(address from, uint256 value, bytes calldata data, bytes calldata operatorData) external {
    _redeem("", msg.sender, from, value, data, operatorData);
  }

}
