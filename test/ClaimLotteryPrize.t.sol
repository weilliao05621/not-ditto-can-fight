// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {Helper} from "test/helper.t.sol";

import {ErrorConfig} from "contracts/NFT/ErrorConfig.sol";

// import {NotDittoConfig} from "contracts/NFT/NotDittoConfig.sol";

// 要記得檢查 vault 價差
contract TestClaimLotteryPrize is ErrorConfig, Helper {
    function setUp() public override {
        super.setUp();
        forkFromSepolia();
    }

    function test_claimLotteryPrize() public {
        // mint a NotDitto and raise it to Lv.30
        uint256 drawIndex = notDittoCanFight.drawIndex();
        assertEq(drawIndex, 1, "ENGAGE: WROND_DRAW_INDEX");
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        uint256 notDittoTokenId = 1;
        raiseNotDittoToMaxLevel(user1, notDittoTokenId);

        // engage in the lottery of draw 1
        uint256[4] memory lotteryNumber = [uint256(1), 2, 3, 4];
        vm.prank(user1);
        notDittoCanFight.engageInLottery(notDittoTokenId, lotteryNumber);

        // user1 start the next draw to get the winning number of draw 1
        vm.prank(user1);
        notDittoCanFight.createNextDraw();
        drawIndex = notDittoCanFight.drawIndex();
        assertEq(drawIndex, 1, "ENGAGE: WROND_DRAW_INDEX"); // keep at 1 for now

        // mock chainlink to give random number back
        uint256 requestId = _mockChainlinkVRF(drawIndex);
        vm.roll(block.number + REQUEST_CONFIRMATIONS);

        // check if the draw is updated
        (bool fulfilled, ) = notDittoCanFight.requests(requestId);
        assertTrue(fulfilled, "ORACLE: SHOULD_BE_FULFILLED");
        drawIndex = notDittoCanFight.drawIndex();

        // check user1 should receive the prize
        uint256 user1PreBalance = user1.balance;
        vm.prank(user1);
        notDittoCanFight.claimLotteryPrize();
        uint256 user1PostBalance = user1.balance;
        uint256 _b = user1PostBalance - user1PreBalance;
        assertEq(_b, 0.0041 ether, "CLAIM-PRIZE: UNCORRECT_PRIZE");

        // prettier-ignore
        bytes32 playerDrawHash = keccak256(abi.encodePacked(msg.sender, notDittoTokenId));

        (, bool engagedLottery) = notDittoCanFight.playerSnapshots(
            drawIndex - 1,
            playerDrawHash
        );

        assertFalse(engagedLottery, "CLAIM-PRIZE: SHOULD_NOT_BE_ENGAGED");

        for (uint256 i = 0; i < 3; i++) {
            uint256 drawIndex = notDittoCanFight.engagedLotteryList(user1, i);
            assertEq(
                drawIndex,
                0,
                "CLAIM-PRIZE: LIST_OF_DRAW_INDEX_SHOULD_BE_EMPTY"
            );
            assertEq(
                notDittoCanFight.engagedDrawByNotDittoIds(user1, i),
                0,
                "CLAIM-PRIZE: LIST_OF_NOT_DITTO_SHOULD_BE_EMPTY"
            );
        }
    }

    function test_claimMultiplePrice() public {
        _user1MintBatchNotDitto(3);
        _user1RaiseTwoNotDittoToMaxLevelAndEngaged();

        // prettier-ignore
        (,bool engagedLottery1) = notDittoCanFight.playerSnapshots(1, keccak256(abi.encodePacked(user1, uint256(1))));
        // prettier-ignore
        (,bool engagedLottery2) = notDittoCanFight.playerSnapshots(1, keccak256(abi.encodePacked(user1, uint256(2))));

        assertTrue(engagedLottery1, "ENGAGE: 1_SHOULD_BE_ENGAGED");
        assertTrue(engagedLottery2, "ENGAGE: 2_SHOULD_BE_ENGAGED");

        vm.prank(user2);
        notDittoCanFight.createNextDraw();
        uint256 drawIndex = notDittoCanFight.drawIndex();
        _mockChainlinkVRF(drawIndex);
        vm.roll(block.number + REQUEST_CONFIRMATIONS);

        uint256 user1PreBalance = user1.balance;
        vm.prank(user1);
        notDittoCanFight.claimLotteryPrize();
        uint256 user1PostBalance = user1.balance;

        uint256 _b = user1PostBalance - user1PreBalance;

        console.log("prize: %s", _b);
        assertEq(_b, 56375000000000000, "CLAIM-PRIZE: UNCORRECT_PRIZE");

        // prettier-ignore
        bytes32 playerDrawHash1 = keccak256(abi.encodePacked(msg.sender, uint256(1)));
        // prettier-ignore
        bytes32 playerDrawHash2 = keccak256(abi.encodePacked(msg.sender, uint256(2)));

        (, bool engagedLottery1) = notDittoCanFight.playerSnapshots(
            drawIndex,
            playerDrawHash1
        );
        (, bool engagedLottery2) = notDittoCanFight.playerSnapshots(
            drawIndex,
            playerDrawHash2
        );

        assertFalse(engagedLottery1);
        assertFalse(engagedLottery2);
    }

    function _user1MintBatchNotDitto(uint256 amount) public {
        // mint NotDittos and raise them to Lv.30
        uint256 mintFee = MINT_PRICE * amount;
        (
            address[] memory nftAddresses,
            uint256[] memory nftIds
        ) = generateNftIdsData(0, amount);
        userMintNewBornBatch(user1, mintFee, amount, nftAddresses, nftIds);
    }

    function _user1RaiseTwoNotDittoToMaxLevelAndEngaged() public {
        vm.startPrank(user1);
        // raise two NotDittos to Lv.30
        uint256 times = 26 days / 3 hours - 3;
        for (uint256 i = 0; i < times; i++) {
            skip(0.125 days);
            notDittoCanFight.claimOfflineReward{value: RASIE_SUPPORT_FEE}(1);
            notDittoCanFight.claimOfflineReward{value: RASIE_SUPPORT_FEE}(2);
        }
        // engage in the lottery of draw 1
        uint256[4] memory lotteryNumber1 = [uint256(5), 5, 5, 5];
        uint256[4] memory lotteryNumber2 = [uint256(5), 6, 7, 7];
        notDittoCanFight.engageInLottery(1, lotteryNumber1);
        notDittoCanFight.engageInLottery(2, lotteryNumber2);
        vm.stopPrank();
    }

    function _mockChainlinkVRF(uint256 drawIndex) public returns (uint256) {
        uint256 requestId = notDittoCanFight.requestIdByDrawIndex(drawIndex);
        vrfCoordinatorV2Mock.fulfillRandomWords(
            requestId,
            address(vrfV2Wrapper)
        );
        return requestId;
    }
}
