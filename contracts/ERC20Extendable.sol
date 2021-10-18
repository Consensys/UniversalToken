
import {UpgradableDelegatedExtendableERC20} from "./tokens/ERC20/base/UpgradableDelegatedExtendableERC20.sol";

contract ERC20Extendable is UpgradableDelegatedExtendableERC20 {
    uint256 constant TOTAL_SUPPLY = 500 ether;

    constructor(string memory name_, string memory symbol_, address core_implementation_) UpgradableDelegatedExtendableERC20(name_, symbol_, core_implementation_) {
        _executeMint(msg.sender, msg.sender, TOTAL_SUPPLY);
    }

    
}