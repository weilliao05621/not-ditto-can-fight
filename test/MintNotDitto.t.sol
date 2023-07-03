// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./setUp.t.sol";

contract TestMintNotDitto is SetUpTest {
    uint256 public constant MINT_PRICE = 0.001 ether;

    function setUp() public override {
        super.setUp();
        // forkFromSepolia();
        _initEther();
    }

    function test_mintNotDittoSigle() public {
        uint256 totalSupplyBefore = notDittoCanFight.totalSupplies(
            NOT_DITTO_ID
        );
        uint256 balanceBefore = notDittoCanFight.balanceOf(user1, NOT_DITTO_ID);
        uint256 nftId;
        address nftAddr;
        address owner;

        (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(
            totalSupplyBefore
        );

        assertEq(owner, address(0), "MINT: INIT_OWNERSHIP");

        vm.prank(user1);
        notDittoCanFight.mintNotDitto{value: MINT_PRICE}(address(nft), 0);

        uint256 totalSupplyAfter = notDittoCanFight.totalSupplies(NOT_DITTO_ID);
        uint256 balanceAfter = notDittoCanFight.balanceOf(user1, NOT_DITTO_ID);
        (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(
            totalSupplyAfter
        );
        bytes32 nftInfoHash = keccak256(abi.encodePacked(nftAddr, nftId));

        assertTrue(
            notDittoCanFight.morphedNftHash(nftInfoHash),
            "BATCH-MINT: MORPHED_NFT_HASH"
        );
        assertEq(nftId, 0, "MINT: MINTED_INDEX");
        assertEq(totalSupplyAfter - totalSupplyBefore, 1, "MINT: TOTAL_SUPPLY");
        assertEq(balanceAfter - balanceBefore, 1, "MINT: BALANCE");
        assertEq(owner, user1, "MINT: MINTED_OWNERSHIP");
        assertEq(nftAddr, address(nft), "MINT: MINTED_NFT_ADDRESS");
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

        uint256 nftId;
        address nftAddr;
        address owner;

        for (uint256 i = 0; i < mintAmount; i++) {
            (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(i + 1);

            assertEq(owner, address(0), "BATCH-MINT: INIT_OWNERSHIP");
            nftAddresses[i] = address(nft);
            nftIds[i] = i;
        }

        vm.prank(user1);
        notDittoCanFight.mintBatchNotDitto{value: MINT_PRICE * mintAmount}(
            mintAmount,
            nftAddresses,
            nftIds
        );

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
