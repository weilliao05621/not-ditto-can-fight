// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {MintHelper} from "test/MintNotDitto/helper.t.sol";

import {ErrorConfig} from "contracts/NFT/ErrorConfig.sol";
import {NotDittoConfig} from "contracts/NFT/NotDittoConfig.sol";

contract TestWithdrawOfflineReward is MintHelper, ErrorConfig, NotDittoConfig {
    function setUp() public override {
        super.setUp();
        // forkFromSepolia();
        _initEther();
    }

    function test_withdrawOfflineReward() public {
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
        notDittoCanFight.withdrawOfflineReward(notDittoId);
        (offlineRewardStartAt, totalExp, effort) = notDittoCanFight
            .notDittoSnapshots(notDittoId);

        assertEq(totalExp, 6400, "OFFLINE-REWARD: TOTAL_EXP");
        assertEq(effort, 1, "OFFLINE-REWARD: EFFORT");
    }
}
