// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NFT/NotDittoAndItems.sol";

import "./libs/Level.sol";
import "./libs/Lottery.sol";

error VaultIsLocked();
error CanAccessToDrawWhenNotDittoFullyGrowTo30(uint256 level);

contract NotDittoCanFight is NotDittoAndItems {
    struct PlaySnapshot {
        uint256[4] lotteryNumber;
        uint256 effort;
        bool engagedLottery;
    }

    uint256 public constant EXCEED_DAYS_MAKE_NOT_DITTO_UNATTENDED = 7;
    mapping(uint256 => mapping(bytes32 => PlaySnapshot)) public playerSnapshots;
    mapping(address => uint256[3]) public engagedLotteryList;

    uint256 public latestDraw;
    mapping(uint256 => uint256[4]) public draws;

    // === NotDitto Lottery === //
    function withdrawLotteryPrize(uint256 draw) external {
        if (vaultIsLock) {
            revert VaultIsLocked();
        }

        uint256[3] memory _engagedLotteryList = engagedLotteryList[msg.sender];
        uint256 reward;

        for (uint256 i = 0; i < _engagedLotteryList.length; ) {
            uint256 lotteryIndex = _engagedLotteryList.length - 1;
            uint256 notDittoIndex = _engagedLotteryList[lotteryIndex];

            bytes32 playerDrawHash = keccak256(
                abi.encodePacked(msg.sender, notDittoIndex)
            );

            PlaySnapshot memory playerSnapshot = playerSnapshots[draw][
                playerDrawHash
            ];

            playerSnapshots[draw][playerDrawHash].engagedLottery = false;
            delete _engagedLotteryList[lotteryIndex];

            require(playerSnapshot.engagedLottery);

            uint256 factor = Lottery._checkLotteryPrize(
                draws[draw],
                playerSnapshot.lotteryNumber
            );

            uint256 effortRefund = playerSnapshot.effort * RASIE_SUPPORT_FEE;
            reward += Lottery._calcPrizeWithFactor(effortRefund, factor);
        }

        engagedLotteryList[msg.sender] = _engagedLotteryList;
        payable(msg.sender).transfer(reward); // TODO: 改用 WETH 來進行
    }

    function engageInLottery(
        uint256 tokenId,
        uint256[4] calldata lotteryNumber
    ) external {
        if (vaultIsLock) {
            revert VaultIsLocked();
        }

        if (!checkIsNotDittoOwner(tokenId)) {
            revert NotOwnerOfTheNotDitto();
        }

        NotDittoSnapshot memory _notDittoSnapshot = notDittoSnapshots[tokenId];
        uint256 totalExp = _notDittoSnapshot.totalExp;
        uint256 currentLevel = Level._getCurrentLevel(totalExp);

        if (currentLevel != 30) {
            revert CanAccessToDrawWhenNotDittoFullyGrowTo30(currentLevel);
        }

        _burnNotDitto(tokenId, false);

        uint256 nextDraw = latestDraw + 1; // TODO: draw 會變成記在 oracle 上的變數
        bytes32 playerDrawHash = keccak256(
            abi.encodePacked(msg.sender, tokenId)
        );
        playerSnapshots[nextDraw][playerDrawHash] = PlaySnapshot(
            lotteryNumber,
            _notDittoSnapshot.effort,
            true
        );
        engagedLotteryList[msg.sender][
            engagedLotteryList[msg.sender].length
        ] = tokenId;
    }

    // 讓遊戲能繼續的機制：確實有可能有人把 NFT 賣了，卻忘記自己有 mint 過 NotDitto
    function takeUnattendedNotDittoToOrphanage(uint256 id) public {
        NotDittoInfo memory _info = notDittoInfos[id];
        require(_info.owner != address(0));

        NotDittoSnapshot memory _snapshot = notDittoSnapshots[id];

        uint256 _offlineRewardStartAt = _snapshot.offlineRewardStartAt;

        uint256 portion = Level._getOfflineRewardPortion(
            block.timestamp - _offlineRewardStartAt
        );
        bool hasTooMuchPortion = portion /
            Level.EXP_DECIMALS /
            EXCEED_DAYS_MAKE_NOT_DITTO_UNATTENDED >
            0;

        require(hasTooMuchPortion);

        _burnNotDitto(id, true);
        // TODO: assign payment if one has took care of our NotDitto
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
