// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract NotDittoConfig {
    // TODO: how to generate different abilities
    struct NotDittoSnapshot {
        uint256 offlineRewardStartAt;
        uint256 totalExp;
        uint256 effort; // this factor will affect the upper amount of prize
    }

    struct NotDittoAsLottery {
        uint256 draw; // 期數 > 如果是 0 表示還沒有參加
        string lotteryNumber; // 開獎號碼
    }

    struct NotDittoInfo {
        uint256 nftId; // record NFT for morphing
        address nftAddress; // record NFT for morphing
        ElementalAttribute elementalAttr;
    }

    // TODO: this may be stored off-chain & calculated by web2 server
    enum ElementalAttribute {
        FIRE,
        WATER,
        GRASS,
        ELECTRIC,
        ICE,
        FIGHTING,
        POISON,
        GROUND,
        FLYING,
        PSYCHIC,
        BUG,
        ROCK,
        DARK,
        DRAGON,
        STEEL,
        FAIRY
    }
}