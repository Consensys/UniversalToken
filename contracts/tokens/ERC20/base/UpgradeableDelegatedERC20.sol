pragma solidity ^0.8.0;

import {ERC20DelegateCore} from "../implementation/core/ERC20DelegateCore.sol";
import {ERC20DelegateProxy} from "../proxy/ERC20DelegateProxy.sol";
import {BaseERC20Storage} from "../storage/BaseERC20Storage.sol";

contract UpgradableERC20 is ERC20DelegateProxy {
    
    constructor(string memory name_, string memory symbol_, address core_implementation_) ERC20DelegateProxy() {
        BaseERC20Storage store = new BaseERC20Storage(name_, symbol_);
        ERC20DelegateCore implementation = ERC20DelegateCore(core_implementation_);

        _setImplementation(address(implementation));
        _setStore(address(store));

        //Only we can modify the storage contract
        //(and the ERC20DelegateCore contract given when we run delegatecall)
        store.changeCurrentWriter(address(this));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);
    }
}