// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import "../interfaces/IERC1155.sol";

import "./NotDittoConfig.sol";

// TODO: 之後比賽獎勵可以獲得的星星，用來加速升等
contract NotDittoAndItems is NotDittoConfig, IERC165, ERC165, IERC1155 {
    uint256 public constant NOT_DITTO = 0;
    uint256 public constant BASIC_STAR = 1;
    uint256 public constant MEDIAN_STAR = 2;
    uint256 public constant LEVEL_UP_STAR = 3;

    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant RASIE_SUPPORT_FEE = (0.001 ether * 250) / 10000; // 2.5%

    uint256 public constant MAX_NOT_DITTO_SUPPLY_PER_ADDRESS = 3;
    uint256 public constant MAX_NOT_DITTO_SUPPLY = 1000;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 public currentNotDittoIndex;

    mapping(uint256 => NotDittoInfo) public notDittoInfos;
    mapping(uint256 => NotDittoSnapshot) public notDittoSnapshots;

    bool public vaultIsLock = true;

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external {}

    // TODO: 通信的機制: 可以轉讓 NFT，但會記錄 NFT 的原持有人有沒有授權
    // 多檢查一種 approval，這樣對方可以花錢借用 NotDitto、可以增加 NotDitto 的屬性
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {}

    function balanceOf(
        address _owner,
        uint256 _id
    ) external view returns (uint256) {
        return _balances[_id][_owner];
    }

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory) {}

    function setApprovalForAll(address _operator, bool _approved) external {}

    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {}

    function ownerOf(uint256 tokenId) public view returns (address owner) {
        owner = notDittoInfos[tokenId].owner;
    }

    function _replaceMorphNFT(
        uint256 tokenId,
        address nftAddr,
        uint256 nftTokenId
    ) external {
        if (!checkIsNotDittoOwner(tokenId)) {
            revert NotOwnerOfTheNotDitto();
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

    function checkIsNotDittoOwner(
        uint256 tokenId
    ) public view returns (bool isOwner) {
        isOwner = msg.sender == ownerOf(tokenId);
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
