pragma solidity ^0.8.0;

import {IToken} from "../IToken.sol";
import {ITokenRoles} from "../../interface/ITokenRoles.sol";
import {IDomainAware} from "../../tools/DomainAware.sol";

interface ITokenProxy is IToken, ITokenRoles, IDomainAware {
    fallback() external payable;

    function upgradeTo(address logic, bytes memory data) external;
}