pragma solidity ^0.8.0;

import { Diamond } from "./Diamond.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { TokenExtensionFacet } from "../facet/TokenExtensionFacet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20ExtendableWithDiamondCut is Diamond {
    constructor(
        string memory name, string memory symbol, uint8 decimals,
        address _contractOwner, 
        address _diamondCutFacet) payable Diamond(_contractOwner, _diamondCutFacet) {
        TokenExtensionFacet extensions = new TokenExtensionFacet();
        
        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = IERC20.totalSupply.selector;
        functionSelectors[1] = IERC20.balanceOf.selector;
        functionSelectors[2] = IERC20.transfer.selector;
        functionSelectors[3] = IERC20.allowance.selector;
        functionSelectors[4] = IERC20.approve.selector;
        functionSelectors[5] = IERC20.transferFrom.selector;
        functionSelectors[6] = TokenExtensionFacet.registerExtension.selector;
        functionSelectors[7] = TokenExtensionFacet.removeExtension.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(extensions), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: functionSelectors
        });
        
        LibDiamond.diamondCut(cut, address(extensions), abi.encodeWithSelector(TokenExtensionFacet._initalize.selector, name, symbol, decimals, _contractOwner));
    }
}