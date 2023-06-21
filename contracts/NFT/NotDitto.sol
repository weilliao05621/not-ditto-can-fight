// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "ERC721A/ERC721A.sol";
import "../interfaces/INotDitto.sol";
import "./NotDittoConfig.sol";

error OnlyGameContractCanCall();
error MaxNotDittoSupplyPerAddressReached();
error MaxNotDittoSupplyReached();
error NotAllowNotDittoToBeSelfMinted();
error NotOwnerOfTheNotDitto(uint256 id, address owner, address msgSender);
error NotDittoIsUnhappyToMorphZeroAddress();

// TODO: 這份 ERC721 也會是獨立、可用的合約，在思考要如無何讓它能獨立運作，又能整合 NotDittoCanFight
contract NotDitto is INotDitto, NotDittoConfig, ERC721A("Not Ditto", "NDCF") {
    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant MAX_NOT_DITTO_SUPPLY_PER_ADDRESS = 3;
    uint256 public constant MAX_NOT_DITTO_SUPPLY = 1000;

    mapping(uint256 => NotDittoInfo) public notDittoInfos;

    address private _gameContract;

    // TODO: 完成 mint 的機制
    function mint(address minter, uint256 amount) external {
        if (msg.sender != _gameContract) {
            revert OnlyGameContractCanCall();
        }

        if (balanceOf(minter) >= MAX_NOT_DITTO_SUPPLY_PER_ADDRESS) {
            revert MaxNotDittoSupplyPerAddressReached();
        }

        if (totalSupply() >= MAX_NOT_DITTO_SUPPLY) {
            revert MaxNotDittoSupplyReached();
        }

        _mint(msg.sender, amount);
    }

    // === NotDitto Info === //
    // TODO: 還需要額外的檢查 > nftAddr 是 ERC721、是 nftAddr 的 ERC721 持有者
    function _replaceMorphNFT(
        uint256 tokenId,
        address nftAddr,
        uint256 nftTokenId
    ) external {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner) {
            revert NotOwnerOfTheNotDitto(tokenId, owner, msg.sender);
        }

        if (nftAddr == address(0)) {
            revert NotDittoIsUnhappyToMorphZeroAddress();
        }

        if (nftTokenId == 0) {
            revert();
        }

        notDittoInfos[tokenId].nftAddress = nftAddr;
        notDittoInfos[tokenId].nftId = nftTokenId;
    }

    function checkIsOwnerOfTokenId(
        address player,
        address nftAddr,
        uint256 tokenId
    ) external view returns (bool isOwner) {
        if (nftAddr == address(this)) {
            revert NotAllowNotDittoToBeSelfMinted();
        }

        bytes memory payload = abi.encodeWithSignature(
            "ownerOf(uint256)",
            tokenId
        );
        (bool success, bytes memory rawOwner) = nftAddr.staticcall(payload);
        require(success, "Controller: failed to call NFT's ownerOf()");
        isOwner = abi.decode(rawOwner, (address)) == player;
    }

    function _getElementalAttribute(
        string calldata _uri
    ) private pure returns (uint256 attribute) {
        attribute = uint8(bytes1(keccak256((abi.encodePacked(_uri))))) / 15;
    }
}
