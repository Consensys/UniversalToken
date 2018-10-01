pragma solidity ^0.4.24;

import "../libs/ERC20/ERC20.sol";
import "../Controllable.sol";
import "../CertificateController.sol";
 
/**
 * @title Basic Token Mock
 * @dev Mock class using BasicToken
 */
contract ControllableERC20Mock is ERC20, CertificateController {
    constructor(
        address initialAccount, 
        uint256 initialBalance
    ) 
        public 
    {
        balances[initialAccount] = initialBalance;
        totalSupply_ = initialBalance;
    }

    /**
     * @dev securized transfer with certificate control
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(
        address _to, 
        uint256 _value
        // uint _expirationTime, TODO: check if it can be passed as hidden argument so we do not transform ERC20 interface 
        // bytes _certificate TODO: check if it can be passed as hidden argument so we do not transform ERC20 interface
    )
        public
        isValidCertificate()
        returns (bool) 
    {
        return transfer(
            _to,
            _value
        );
    }
}