pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
* @dev This is the base contract that will be extended by all 
* Extendable contracts. Provides _msgSender() functions through
* the ContextUpgradeable contract
*/
abstract contract ExtendableBase is ContextUpgradeable {
}