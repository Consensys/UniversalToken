pragma solidity ^0.8.0;

import {IToken} from "../../IToken.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC721ExtendableHooks} from "../extensions/ERC721ExtendableHooks.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyContext} from "../../../proxy/context/ProxyContext.sol";
import {TransferData} from "../../../extensions/ERC20/IERC20Extension.sol";
import {TokenRoles} from "../../roles/TokenRoles.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";

contract ERC721Logic is ERC721, ERC1820Client, ERC1820Implementer, ERC721ExtendableHooks, ProxyContext, IToken {
    string constant internal ERC721_LOGIC_INTERFACE_NAME = "ERC721TokenLogic";

    bytes private _currentData;
    bytes private _currentOperatorData;

    constructor() ERC721("", "") {
        ERC1820Client.setInterfaceImplementation(ERC721_LOGIC_INTERFACE_NAME, address(this));
        ERC1820Implementer._setInterface(ERC721_LOGIC_INTERFACE_NAME); // For migration
    }

    function _msgSender() internal view override(Context, ProxyContext) returns (address) {
        return ProxyContext._msgSender();
    }

    /**
    * @dev Override internal _safeTransfer to ensure _data gets passed
    * to extensions.
    */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal override {
        _currentData = _data;
        super._safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        TransferData memory data = TransferData(
            _callsiteAddress(),
            msg.data,
            0x00000000000000000000000000000000,
            _msgSender(),
            from,
            to,
            0,
            tokenId,
            _currentData,
            _currentOperatorData
        );

        _currentData = "";
        _currentOperatorData = "";

        //TODO Are both needed?
        _triggerBeforeTokenTransfer(data);
        _triggerAfterTokenTransfer(data);
    }

    function _isMinter(address caller) internal view returns (bool) {
        address tokenProxy = _callsiteAddress();

        uint size;
        assembly { size := extcodesize(tokenProxy) }
        bool isTokenBeingConstructed = size == 0;

        if (isTokenBeingConstructed) {
            return true;
        }

        TokenRoles proxy = TokenRoles(tokenProxy);
        bool minter = proxy.isMinter(caller);
        return minter;
    }

    //TODO Add mint

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }

    function tokenTransfer(TransferData calldata td) external override returns (bool) {
        require(td.partition == bytes32(0), "Invalid transfer data: partition");
        require(td.token == _callsiteAddress(), "Invalid transfer data: token");
        require(td.value == 0, "Invalid transfer data: value");

        _currentData = td.data;
        _currentOperatorData = td.operatorData;
        _safeTransfer(td.from, td.to, td.value, td.data);

        return true;
    }
}