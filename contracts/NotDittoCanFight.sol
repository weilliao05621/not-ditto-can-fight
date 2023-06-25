// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NFT/NotDittoAndItems.sol";

import "./libs/Strings.sol";
import "./libs/Level.sol";

error VaultIsLocked();
error NotOnPendingLotteryList();
error PendingLotteryListIsFull();
error InvalidLotteryNumberLength(string lotteryNumber);
error CanAccessToDrawWhenNotDittoFullyGrowTo30(uint256 level);

contract NotDittoCanFight is NotDittoAndItems {
    // === NotDitto Lottery === //
    function withdrawLotteryPrize(uint256 tokenId) external {
        if (vaultIsLock) {
            revert VaultIsLocked();
        }

        if (!checkIsNotDittoOwner(tokenId)) {
            revert NotOwnerOfTheNotDitto();
        }

        uint256 mutipler = 1; // TODO: will be calc by controll from oracle and its draw
        uint256 effortRefund = notDittoSnapshots[tokenId].effort *
            RASIE_SUPPORT_FEE;
        uint256 reward = mutipler * effortRefund;

        notDittoSnapshots[tokenId] = NotDittoSnapshot(
            block.timestamp,
            0,
            0,
            0,
            ""
        );

        payable(msg.sender).transfer(reward); // 改用 WETH 來進行
    }

    // 確認是否要拿滿等的 NotDitto 參賽
    // TODO: 要確定是比較排列組合，而不是單純比數字
    function engageInLottery(uint256 tokenId, uint256 lotteryNumber) external {
        if (vaultIsLock) {
            revert VaultIsLocked();
        }

        if (!checkIsNotDittoOwner(tokenId)) {
            revert NotOwnerOfTheNotDitto();
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
    function withdrawOfflineReward(uint256 tokenId) external {
        if (!checkIsNotDittoOwner(tokenId)) {
            revert NotOwnerOfTheNotDitto();
        }
        // TODO: 如果是 0 等要提領，會把 allowTransfered 調成 false 
        NotDittoSnapshot memory _snapshot = notDittoSnapshots[tokenId];

        uint256 startAt = _snapshot.offlineRewardStartAt;
        uint256 effort = _snapshot.effort;
        uint256 level = Level._getCurrentLevel(_snapshot.totalExp);

        unchecked {
            uint256 duration = block.timestamp - startAt;

            uint256 portion = Level._getOfflineRewardPortion(duration);
            uint256 updatedTotalExp = _snapshot.totalExp +
                portion *
                Level._calcOfflineRewardPerDay(effort, level);

            notDittoSnapshots[tokenId].offlineRewardStartAt = block.timestamp;
            notDittoSnapshots[tokenId].totalExp = updatedTotalExp;
            notDittoSnapshots[tokenId].effort = effort + 1;
        }
    }
}
