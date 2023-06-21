// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract NotDittoConfig {
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