// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SetUpTest} from "test/setUp.t.sol";

import {ErrorConfig} from "contracts/NFT/ErrorConfig.sol";
import {Helper} from "test/MintNotDitto/helper.t.sol";

contract TestMintNotDittoBatch is Helper, ErrorConfig {
    function setUp() public override {
        super.setUp();
        // forkFromSepolia();
        _initEther();
    }

    // record: notDitto's id starts from 1
    // error: 測出在判斷 allNotDittoIsMinted 後，忘記先去檢查 newBorns + orphans 有沒有辦法符合 mint
    function test_mintNotDittoBatch() public {
        uint256 totalSupplyBefore = notDittoCanFight.totalSupplies(
            NOT_DITTO_ID
        );
        uint256 balanceBefore = notDittoCanFight.balanceOf(user1, NOT_DITTO_ID);

        address[] memory nftAddresses = new address[](3);
        uint256[] memory nftIds = new uint256[](3);
        uint256 mintAmount = 3;
        uint256 mintFee = MINT_PRICE * mintAmount;

        uint256 nftId;
        address nftAddr;
        address owner;

        for (uint256 i = 0; i < mintAmount; i++) {
            (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(i + 1);

            assertEq(owner, address(0), "BATCH-MINT: INIT_OWNERSHIP");
            nftAddresses[i] = address(nft);
            nftIds[i] = i;
        }

        userMintNewBornBatch(user1, mintFee, mintAmount, nftAddresses, nftIds);

        for (uint256 i = 0; i < mintAmount; i++) {
            (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(i + 1);
            bytes32 nftInfoHash = keccak256(abi.encodePacked(nftAddr, nftId));
            assertTrue(
                notDittoCanFight.morphedNftHash(nftInfoHash),
                "BATCH-MINT: MORPHED_NFT_HASH"
            );
            assertEq(nftId, i, "BATCH-MINT: MINTED_INDEX");
            assertEq(owner, user1, "BATCH-MINT: MINTED_OWNERSHIP");
            assertEq(nftAddr, address(nft), "BATCH-MINT: MINTED_NFT_ADDRESS");
        }

        uint256 totalSupplyAfter = notDittoCanFight.totalSupplies(NOT_DITTO_ID);
        uint256 balanceAfter = notDittoCanFight.balanceOf(user1, NOT_DITTO_ID);

        assertEq(
            totalSupplyAfter - totalSupplyBefore,
            mintAmount,
            "MINT: TOTAL_SUPPLY"
        );
        assertEq(balanceAfter - balanceBefore, mintAmount, "MINT: BALANCE");
    }
}
