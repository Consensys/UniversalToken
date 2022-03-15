pragma solidity ^0.8.0;

import {TokenLogic} from "../TokenLogic.sol";
import {IToken, TokenStandard} from "../../../interface/IToken.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {TransferData} from "../../../extensions/IExtension.sol";
import {TokenRoles} from "../../../roles/TokenRoles.sol";
import {ERC1820Client} from "../../../erc1820/ERC1820Client.sol";
import {ERC1820Implementer} from "../../../erc1820/ERC1820Implementer.sol";
import {ITokenLogic} from "../../../interface/ITokenLogic.sol";
import {ERC721TokenInterface} from "../../registry/ERC721TokenInterface.sol";

contract ERC721Logic is ERC721TokenInterface, TokenLogic, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable {
    bytes private _currentData;
    bytes private _currentOperatorData;

    string internal _contractUri;


    //TODO Add upgrade check
    function initialize(bytes memory data) external override {
        //require(msg.sender == address(this), "Unauthorized");
        require(_onInitialize(data), "Initialize failed");
    }

    function _onInitialize(bytes memory data) internal virtual returns (bool) {
        return true;
    }

    /**
    * @dev Function to mint tokens
    * @param to The address that will receive the minted tokens.
    * @param tokenId The token id to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address to, uint256 tokenId) public onlyMinter returns (bool) {
        _mint(to, tokenId);
        return true;
    }
    
    function mintAndSetTokenURI(address to, uint256 tokenId, string memory uri) public onlyMinter returns (bool) {
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return true;
    }

    function setTokenURI(uint256 tokenId, string memory uri) public virtual onlyMinter {
        _setTokenURI(tokenId, uri);
    }

    /**
    * @dev Override internal _safeTransfer to ensure _data gets passed
    * to extensions.
    */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal override {
        _currentData = _data;
        super._safeTransfer(from, to, tokenId, _data);
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function setContractURI(string memory uri) public virtual onlyOwner {
        _contractUri = uri;
    }

    function contractURI() public view returns (string memory) {
        return _contractUri;
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
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        ERC721EnumerableUpgradeable._beforeTokenTransfer(from, to, tokenId);

        TransferData memory data = TransferData(
            address(this),
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

        _triggerTokenTransfer(data);
    }

    function tokenTransfer(TransferData calldata td) external override returns (bool) {
        require(td.partition == bytes32(0), "Invalid transfer data: partition");
        require(td.token == address(this), "Invalid transfer data: token");
        require(td.value == 0, "Invalid transfer data: value");

        _currentData = td.data;
        _currentOperatorData = td.operatorData;
        _safeTransfer(td.from, td.to, td.value, td.data);

        return true;
    }

    function tokenStandard() external pure override returns (TokenStandard) {
        return TokenStandard.ERC721;
    }
}