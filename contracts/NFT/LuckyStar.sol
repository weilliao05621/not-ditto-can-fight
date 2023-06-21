// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import "../interfaces/IERC1155.sol";

// TODO: 之後比賽獎勵可以獲得的星星，用來加速升等
contract LuckyStar is IERC165, ERC165, IERC1155 {
    uint256 public constant BASIC_STAR = 0;
    uint256 public constant MEDIAN_STAR = 1;
    uint256 public constant LEVEL_UP_STAR = 2;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

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
    // 多檢查一種 approval，這樣對方可以花錢借用 NotDitto、就不用大家都有 3 隻 NotDitto 才能打比賽
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
    ) external view returns (uint256) {}

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory) {}

    function setApprovalForAll(address _operator, bool _approved) external {}

    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {}
}
