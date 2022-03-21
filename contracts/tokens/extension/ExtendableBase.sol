pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
* @title Base Contract for Extendable contracts
* @author Edward Penta
* @notice This is an abstract contract that should only be used by other
* contracts in this folder
* @dev This is the base contract that will be extended by all 
* Extendable contracts. Provides _msgSender() functions through
* the ContextUpgradeable contract
*/
abstract contract ExtendableBase is ContextUpgradeable {
}