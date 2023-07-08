// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NotDittoConfig.sol";
import "./ErrorConfig.sol";

contract NotDittoAndItemsStorage is ErrorConfig, NotDittoConfig {
    uint256 public constant NOT_DITTO = 0;
    uint256 public constant BASIC_STAR = 1;
    uint256 public constant MEDIAN_STAR = 2;
    uint256 public constant LEVEL_UP_STAR = 3;

    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant RASIE_SUPPORT_FEE = (MINT_PRICE * 250) / 10000; // 2.5%

    uint256 public constant MAX_NOT_DITTO_SUPPLY_PER_ADDRESS = 3;
    uint256 public constant MAX_NOT_DITTO_SUPPLY = 10; // TODO: 先用 10 隻做測試，最多只支援 1_000

    // tokenId => owner => amount
    mapping(uint256 => mapping(address => uint256)) _balances;
    // tokenId => totalSupply
    uint256[4] public totalSupplies;

    // notDittoId => operator => bool
    mapping(uint256 => mapping(address => bool)) _approvals;
    mapping(address => mapping(address => bool)) _operatorApprovals;

    // 為了減省 gas，所以會採 stack 的方式達成 re-mint
    uint256[] public currentOrphanNotDittos;

    mapping(bytes32 => bool) public morphedNftHash;
    mapping(uint256 => NotDittoInfo) public notDittoInfos;
    mapping(uint256 => NotDittoSnapshot) public notDittoSnapshots;
}
