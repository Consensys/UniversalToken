pragma solidity ^0.4.23;

import "../BasicToken.sol";

 
/**
 * @title Basic Token Mock
 * @dev Mock class using BasicToken
 */
contract BasicTokenMock is BasicToken {

  constructor(address initialAccount, uint256 initialBalance) public {
    balances[initialAccount] = initialBalance;
    totalSupply_ = initialBalance;
  }

}