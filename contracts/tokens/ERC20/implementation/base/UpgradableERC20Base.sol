pragma solidity ^0.8.0;

import {ERC20LogicBase} from "../../implementation/logic/ERC20LogicBase.sol";
import {ERC20ProxyBase} from "../../proxy/ERC20ProxyBase.sol";
import {ERC20Storage} from "../../storage/ERC20Storage.sol";

contract UpgradableERC20Base is ERC20ProxyBase {
    
    constructor(
        string memory name_, string memory symbol_,
        bool allowMint, bool allowBurn, address owner
    ) ERC20ProxyBase(allowMint, allowBurn, owner) {
        ERC20Storage store = new ERC20Storage(name_, symbol_);
        ERC20LogicBase implementation = new ERC20LogicBase(address(this), address(store));

        _setImplementation(address(implementation));
        _setStore(address(store));

        store.changeCurrentWriter(address(implementation));
    }

    function upgradeTo(address implementation) external onlyManager {
        _setImplementation(implementation);

        _getStorageContract().changeCurrentWriter(implementation);
    }
}