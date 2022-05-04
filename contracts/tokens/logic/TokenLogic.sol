pragma solidity ^0.8.0;

import {ITokenLogic} from "./ITokenLogic.sol";
import {TokenRoles} from "../../utils/roles/TokenRoles.sol";
import {ExtendableHooks} from "../extension/ExtendableHooks.sol";
import {ERC1820Client} from "../../utils/erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../utils/erc1820/ERC1820Implementer.sol";
import {TokenERC1820Provider} from "../TokenERC1820Provider.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

/**
* @title Base Token Logic Contract
* @notice This should be inherited by the token logic contract
* @dev An abstract contract to be inherited by a token logic contract. This contract
* inherits from TokenERC1820Provider, TokenRoles and ExtendableHooks. It is recommended
* that a token logic contract inherit from a TokenERC1820Provider contract or implement those functions.
*
* This contract uses the TokenERC1820Provider to automatically register the required token logic
* interface name to the ERC1820 registry. This is used by the token proxy contract to lookup the current
* token logic address.
*
* The child contract should override _onInitialize to determine how the logic contract should initalize
* when it's attached to a proxy. This occurs during deployment and during upgrading.
*/
abstract contract TokenLogic is TokenERC1820Provider, TokenRoles, ExtendableHooks, ITokenLogic {
    using BytesLib for bytes;

    bytes32 private constant UPGRADING_FLAG_SLOT = keccak256("token.proxy.upgrading");

    /**
    * @dev Register token logic interfaces to the ERC1820 registry. These
    * interface names are provided by TokenERC1820Provider implementing contract.
    */
    constructor() {
        ERC1820Client.setInterfaceImplementation(__tokenLogicInterfaceName(), address(this));
        ERC1820Implementer._setInterface(__tokenLogicInterfaceName()); // For migration
    }

    function _extractExtraCalldata(uint256 normalCallsize) internal view returns (bytes memory) {
        bytes memory cdata = _msgData();

        if (cdata.length > normalCallsize) {
            //Start the slice from where the normal 
            //parameter arguments should end
            uint256 start = normalCallsize;

            //The size of the slice will be the difference
            //in expected size to actual size
            uint256 size = cdata.length - normalCallsize;
 
            bytes memory extraData = cdata.slice(start, size);

            return extraData;
        }
        return bytes("");
    }

    /**
    * @notice This cannot be invoked directly. It must be invoked by a TokenProxy inside of upgradeTo or 
    * in the consturctor.
    * 
    * @dev This function can only be invoked if the uint256 value in the UPGRADING_FLAG_SLOT storage slot
    * is non-zero and matches the length of the data provided
    *
    * @param data The data to initalize with
    */
    function initialize(bytes memory data) external override {
        uint256 upgradeChallengeCheck = StorageSlot.getUint256Slot(UPGRADING_FLAG_SLOT).value;
        require(upgradeChallengeCheck != 0 && upgradeChallengeCheck == data.length, "The contract is not upgrading or was invoked incorrectly");

        require(_onInitialize(data), "Initialize failed");
    }

    /**
    * @dev To be implemented by the child logic contract. This function is invoked when the logic
    * contract is attached to the proxy, either through the constructor or when upgrading. When
    * attached during deployment, the data length will be the encoded constructor arguments inside
    * TokenProxy. When attached inside upgradeTo, the data passed along with the upgradeTo call will
    * be passed here.
    *
    * @param data The data to initalize with
    */
    function _onInitialize(bytes memory data) internal virtual returns (bool);
}