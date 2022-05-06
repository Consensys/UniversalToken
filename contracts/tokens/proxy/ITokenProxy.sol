pragma solidity ^0.8.0;

import {IToken} from "../IToken.sol";
import {ITokenRoles} from "../../utils/roles/ITokenRoles.sol";
import {IDomainAware} from "../../utils/DomainAware.sol";

interface ITokenProxy is IToken, ITokenRoles, IDomainAware {
    fallback() external payable;

    receive() external payable;

    function upgradeTo(address logic, bytes memory data) external;
}