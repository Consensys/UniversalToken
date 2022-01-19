pragma solidity ^0.8.0;

/**
* @dev Verify if a token transfer can be executed or not, on the validator's perspective.
* @param token Token address that is executing this extension.
* @param payload The full payload of the initial transaction.
* @param partition Name of the partition (left empty for ERC20 transfer).
* @param operator Address which triggered the balance decrease (through transfer or redemption).
* @param from Token holder.
* @param to Token recipient for a transfer and 0x for a redemption.
* @param value Number of tokens the token holder balance is decreased by.
* @param data Extra information (if any).
* @param operatorData Extra information, attached by the operator (if any).
*/
struct TransferData {
    address token;
    bytes payload;
    bytes32 partition;
    address operator;
    address from;
    address to;
    uint value;
    bytes data;
    bytes operatorData;
}

/**
* @dev A standard interface all token standards must inherit from. Provides token standard agnostic 
* functions
*/
interface IToken {
    /**
    * @dev Perform a transfer given a TransferData struct. 
    * @return If this contract does not support the transfer requested, it should return false. 
    * If the contract does support the transfer but the transfer is impossible, it should revert. 
    * If the contract does support the transfer and successfully performs the transfer, it should return true
    */
    function transfer(TransferData calldata transfer) external returns (bool);
}