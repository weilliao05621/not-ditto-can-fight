// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract NotDittoConfig {
    struct NotDittoInfo {
        uint256 nftId; // record NFT for morphing
        address nftAddress; // record NFT for morphing
        uint256 elementalAttr;
        address owner;
    }

    struct NotDittoSnapshot {
        uint256 offlineRewardStartAt;
        uint256 totalExp;
        uint256 effort; // this factor will affect the upper amount of prize
    }
}
