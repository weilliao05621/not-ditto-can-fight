// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {Helper} from "test/helper.t.sol";

import {ErrorConfig} from "contracts/NFT/ErrorConfig.sol";
import {NotDittoConfig} from "contracts/NFT/NotDittoConfig.sol";

// record: 14天(2 weeks)都每三小時領一次，會到20等
// record: 28天(4 weeks)都每三小時領一次，會超過太多 > 41673600
// record: 21天(3 weeks)都每三小時領一次，會到27等 > 22257600
// record: 24.5天(3.5 weeks)都每三小時領一次，會到27等 > 27331200
// record: 26天 都每三小時領一次，會到滿等 > 31161600

contract TestClaimOfflineReward is Helper, ErrorConfig, NotDittoConfig {
    function setUp() public override {
        super.setUp();
        // forkFromSepolia();
        localTesting();
    }

    function test_claimOfflineReward() public {
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        uint256 notDittoId = 1;
        uint256 offlineRewardStartAt;
        uint256 totalExp;
        uint256 effort;

        (offlineRewardStartAt, totalExp, effort) = notDittoCanFight
            .notDittoSnapshots(notDittoId);

        assertEq(
            offlineRewardStartAt,
            block.timestamp,
            "INIT: OFFLINE_REWARD_START_AT"
        );

        assertEq(totalExp, 0, "INIT: TOTAL_EXP");
        assertEq(effort, 0, "INIT: EFFORT");

        skip(1 days); // will have 8 portions by lv 1
        vm.prank(user1);
        notDittoCanFight.claimOfflineReward{value: RASIE_SUPPORT_FEE}(
            notDittoId
        );
        (offlineRewardStartAt, totalExp, effort) = notDittoCanFight
            .notDittoSnapshots(notDittoId);

        assertEq(totalExp, 6400, "OFFLINE-REWARD: TOTAL_EXP");
        assertEq(effort, 1, "OFFLINE-REWARD: EFFORT");
    }

    // record: 因此比較建議要一直 claim
    function test_claimOfflineRewardPerPortionForOneDay() public {
        uint256 notDittoId = 1;
        uint256 times = 1 days / 3 hours;
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        claimOfflineRewardWithPortion(8, notDittoId,user1);

        (, uint256 totalExp, uint256 effort) = notDittoCanFight
            .notDittoSnapshots(notDittoId);

        assertEq(totalExp, 31200, "OFFLINE-REWARD: TOTAL_EXP");
        assertEq(effort, 8, "OFFLINE-REWARD: EFFORT");
    }

    function test_claimOfflineRewardPerPortionForTwoWeek() public {
        uint256 notDittoId = 1;
        uint256 times = 2 weeks / 3 hours;
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        claimOfflineRewardWithPortion(112, notDittoId,user1);

        (, uint256 totalExp, uint256 effort) = notDittoCanFight
            .notDittoSnapshots(notDittoId);

        assertEq(totalExp, 9651200, "OFFLINE-REWARD: TOTAL_EXP");
        assertEq(effort, 112, "OFFLINE-REWARD: EFFORT");
    }

    function test_claimOfflineRewardPerPortionTillMaxLevel() public {
        uint256 notDittoId = 1;
        uint256 times = 26 days / 3 hours;
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        claimOfflineRewardWithPortion(times, notDittoId,user1);

        (, uint256 totalExp, uint256 effort) = notDittoCanFight
            .notDittoSnapshots(notDittoId);

        assertEq(totalExp, 31161600, "OFFLINE-REWARD: TOTAL_EXP");
        assertEq(effort, times, "OFFLINE-REWARD: EFFORT");
    }

    function test_revertWhenClaimExpWithoutOwnership() public {
        uint256 notDittoId = 1;
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NOT_DITTO)
            )
        );
        notDittoCanFight.claimOfflineReward(notDittoId);
        vm.stopPrank();
    }

    function test_revertWhenClaimWithoutEnoughRaiseFee() public {
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        uint256 notDittoId = 1;
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.NOT_ENOUGH_RAISE_SUPPORT_FEE)
            )
        );
        notDittoCanFight.claimOfflineReward{value: RASIE_SUPPORT_FEE - 1}(
            notDittoId
        );
        vm.stopPrank();
    }
}
