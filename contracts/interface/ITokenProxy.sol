pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";
import {ITokenRoles} from "./ITokenRoles.sol";
import {IDomainAware} from "../tools/DomainAware.sol";
import {IExtendable} from "../tokens/extension/IExtendable.sol";

interface ITokenProxy is IToken, IExtendable, ITokenRoles, IDomainAware {
    fallback() external payable;

    receive() external payable;

    function upgradeTo(address logic, bytes memory data) external;
}