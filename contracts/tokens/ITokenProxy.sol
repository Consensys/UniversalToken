pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";
import {ITokenRoles} from "./roles/ITokenRoles.sol";
import {IDomainAware} from "../tools/DomainAware.sol";

interface ITokenProxy is IToken, ITokenRoles, IDomainAware {
    fallback() external payable;

    receive() external payable;

    function contextAddressForExtension(address extension) external view returns (address);

    function allExtensions() external view returns (address[] memory);

    function enableExtension(address extension) external returns (bool);

    function disableExtension(address extension) external returns (bool);

    function removeExtension(address extension) external returns (bool);

    function registerExtension(address extension) external returns (bool);

    function upgradeTo(address implementation, bytes memory data) external;
}