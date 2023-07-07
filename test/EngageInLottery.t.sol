// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {Helper} from "test/helper.t.sol";

import {ErrorConfig} from "contracts/NFT/ErrorConfig.sol";
import {NotDittoConfig} from "contracts/NFT/NotDittoConfig.sol";

contract TestEngageInLottery is ErrorConfig, NotDittoConfig, Helper {
    function setUp() public override {
        super.setUp();
        // forkFromSepolia();
        localTesting();
    }

    function test_engageInDraw() public {
        uint256 drawIndex = notDittoCanFight.drawIndex();
        assertEq(drawIndex, 1, "ENGAGE: WROND_DRAW_INDEX");
        uint256 notDittoTokenId = 1;
        uint256 times = 26 days / 3 hours;
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        claimOfflineRewardWithPortion(times, notDittoTokenId, user1);

        uint256[4] memory lotteryNumber = [uint256(1), 2, 3, 4];

        vm.prank(user1);
        notDittoCanFight.engageInLottery(notDittoTokenId, lotteryNumber);

        assertEq(notDittoCanFight.totalOrphans(), 1, "MINT: ORPHANS");

        uint256 orphanIndex = notDittoCanFight.currentOrphanNotDittos(0);
        assertEq(orphanIndex, 1, "MINT: ORPHANS_INDEX");

        bytes32 playerHash = keccak256(
            abi.encodePacked(user1, notDittoTokenId)
        );
        (uint256 effort, bool engaged) = notDittoCanFight.playerSnapshots(
            drawIndex,
            playerHash
        );
        uint256[4] memory _lotteryNumber = notDittoCanFight
            .getLotteryNumberByEngagedNumber(drawIndex, user1, notDittoTokenId);
        uint256[3] memory _engagedLotteryList = notDittoCanFight
            .getEngagedLotteryList(user1);

        for (uint256 i = 0; i < lotteryNumber.length; i++) {
            assertEq(
                _lotteryNumber[i],
                lotteryNumber[i],
                "ENGAGE: LOTTERY_NUMBER"
            );
        }
        assertEq(_engagedLotteryList[0], notDittoTokenId, "ENGAGE: ENGAGED");
        assertEq(effort, times, "ENGAGE: EFFORT");
        assertTrue(engaged, "ENGAGE: ENGAGED");
        assertEq(
            notDittoCanFight.ownerOf(notDittoTokenId),
            address(0),
            "ENGAGE: BURN"
        );
    }

    function test_revertWhenEngageLotteryWithTheSameNotDitto() public {
        uint256 notDittoTokenId = 1;
        mintAllNewBorn();
        uint256 totalSupplies = notDittoCanFight.totalSupplies(0);
        assertEq(totalSupplies, 10, "MINT: NOT_DITTO_TOTAL_SUPPLIES");

        raiseNotDittoToMaxLevel(user1, notDittoTokenId);
        engageLottery(user1, notDittoTokenId);

        vm.prank(user1);
        notDittoCanFight.mintNotDitto{value: MINT_PRICE}(address(nft), 0);
        assertEq(notDittoCanFight.totalOrphans(), 0, "MINT: ADOPT_ORPHANS");
        raiseNotDittoToMaxLevel(user1, notDittoTokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.ALREADY_ENGAGED_IN_THIS_DRAW)
            )
        );

        engageLottery(user1, notDittoTokenId);
    }

    function test_revertWhenTakeNotDittoWithoutOwnership() public {
        userMintNewBornSingle(user1, MINT_PRICE, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(
                    ErrorNotDitto.NOT_OWNER_OF_THE_NOT_DITTO
                )
            )
        );

        uint256 notDittoTokenId = 1;
        engageLottery(user2, notDittoTokenId);
    }

    function test_revertWhenTakeNonMaxLevelNotDitto() public {
        userMintNewBornSingle(user1, MINT_PRICE, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(
                    ErrorNotDitto.SHOULD_ACCESS_TO_DRAW_WITH_MAX_LV_NOT_DITTO
                )
            )
        );
        uint256 notDittoTokenId = 1;
        engageLottery(user1, notDittoTokenId);
    }
}
