// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NFT/LuckyStar.sol";
import "./NFT/NotDittoConfig.sol";
import "./NFT/NotDitto.sol";

import "./libs/Strings.sol";
import "./libs/Level.sol";

error VaultIsLocked();
error NotOnPendingLotteryList();
error PendingLotteryListIsFull();
error InvalidLotteryNumberLength(string lotteryNumber);
error CanAccessToDrawWhenNotDittoFullyGrowTo30(uint256 level);

contract NotDittoCanFight is LuckyStar {
    struct NotDittoSnapshot {
        uint256 offlineRewardStartAt;
        uint256 totalExp;
        uint256 effort; // this factor will affect the upper amount of prize
        uint256 draw; // 期數 > 如果是 0 表示還沒有參加
        string lotteryNumber; // 開獎號碼
    }

    uint256 public constant RASIE_SUPPORT_FEE = (0.001 ether * 250) / 10000; // 2.5%

    mapping(uint256 => address) public owners;
    mapping(uint256 => NotDittoSnapshot) public notDittoSnapshots;

    bool public vaultIsLock = true;

    // === NotDitto Lottery === //
    function withdrawLotteryPrize(uint256 tokenId) external {
        if (vaultIsLock) {
            revert VaultIsLocked();
        }
        if (msg.sender != owners[tokenId]) {
            revert NotOwnerOfTheNotDitto(tokenId, owners[tokenId], msg.sender);
        }

        uint256 mutipler = 1; // TODO: will be calc by controll from oracle and its draw
        uint256 effortRefund = notDittoSnapshots[tokenId].effort *
            RASIE_SUPPORT_FEE;
        uint256 reward = mutipler * effortRefund;

        notDittoSnapshots[tokenId] = NotDittoSnapshot(block.timestamp, 0, 0,0,"");

        payable(msg.sender).transfer(reward);
    }

    // 確認是否要拿滿等的 NotDitto 參賽
    // TODO: 要確定是比較排列組合，而不是單純比數字
    function engageInLottery(uint256 tokenId, uint256 lotteryNumber) external {
        if (vaultIsLock) {
            revert VaultIsLocked();
        }

        if (msg.sender != owners[tokenId]) {
            revert NotOwnerOfTheNotDitto(tokenId, owners[tokenId], msg.sender);
        }

        _engageInLottery(tokenId, lotteryNumber);
    }

    function _engageInLottery(uint256 tokenId, uint256 lotteryNumber) internal {
        string memory lotteryNumberToString = Strings.toLotteryNumberString(
            lotteryNumber
        );

        NotDittoSnapshot memory _snapshot = notDittoSnapshots[tokenId];

        uint256 totalExp = notDittoSnapshots[tokenId].totalExp;

        uint256 currentLevel = Level._getCurrentLevel(totalExp);

        if (currentLevel != 30) {
            revert CanAccessToDrawWhenNotDittoFullyGrowTo30(currentLevel);
        }

        notDittoSnapshots[tokenId].totalExp = 0; // prevent suddenly draw again

        uint256 nextDraw = 1; // TODO: controller will fetch draw
        _snapshot.draw = nextDraw;
        _snapshot.lotteryNumber = lotteryNumberToString;

        notDittoSnapshots[tokenId] = _snapshot;
    }

    // === NotDitto Level === //
    function withdrawOfflineReward(uint256 id) external {
        if (msg.sender != owners[id]) {
            revert NotOwnerOfTheNotDitto(id, owners[id], msg.sender);
        }

        NotDittoSnapshot memory _snapshot = notDittoSnapshots[id];

        uint256 startAt = _snapshot.offlineRewardStartAt;
        uint256 effort = _snapshot.effort;
        uint256 level = Level._getCurrentLevel(_snapshot.totalExp);

        unchecked {
            uint256 duration = block.timestamp - startAt;

            uint256 portion = Level._getOfflineRewardPortion(duration);
            uint256 updatedTotalExp = _snapshot.totalExp +
                portion *
                Level._calcOfflineRewardPerDay(effort, level);

            notDittoSnapshots[id].offlineRewardStartAt = block.timestamp;
            notDittoSnapshots[id].totalExp = updatedTotalExp;
            notDittoSnapshots[id].effort = effort + 1;
        }
    }
}
