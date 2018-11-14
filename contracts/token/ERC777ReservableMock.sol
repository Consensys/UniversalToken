pragma solidity ^0.4.24;
import "../token/ERC777/ERC777Reservable.sol";
import "../mocks/ControllerMock.sol";


contract ERC777ReservableMock is ERC777Reservable, ControllerMock {

constructor(
	string name,
	string symbol,
	uint256 granularity,
    address[] defaultOperators,
    uint256 minShares,
    uint256 maxShares,
    bool burnLeftOver,
    address certificateSigner //0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630
  )
    public
    ERC777Reservable(name, symbol, granularity, defaultOperators, minShares, maxShares, burnLeftOver, certificateSigner)
  { 
  }

}