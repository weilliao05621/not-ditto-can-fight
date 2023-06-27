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
    struct PlaySnapshot {
        string lotteryNumber;
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
            uint256 notDittoIndex = _engagedLotteryList[
                _engagedLotteryList.length - 1
            ];

            bytes32 playerDrawHash = keccak256(
                abi.encodePacked(msg.sender, notDittoIndex)
            );

            PlaySnapshot memory playerSnapshot = playerSnapshots[draw][
                playerDrawHash
            ];
            
            require(playerSnapshot.engagedLottery);

            uint256 mutipler = 1; // TODO: will be calc by controll from oracle and its draw
            uint256 effortRefund = playerSnapshot.effort * RASIE_SUPPORT_FEE;
            reward += mutipler * effortRefund;
        }

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
        NotDittoSnapshot memory _notDittoSnapshot = notDittoSnapshots[tokenId];
        uint256 totalExp = _notDittoSnapshot.totalExp;
        uint256 currentLevel = Level._getCurrentLevel(totalExp);

        if (currentLevel != 30) {
            revert CanAccessToDrawWhenNotDittoFullyGrowTo30(currentLevel);
        }

        string memory lotteryNumberToString = Strings.toLotteryNumberString(
            lotteryNumber
        );

        _burnNotDitto(tokenId, false);

        uint256 nextDraw = latestDraw + 1; // TODO: draw 會變成記在 oracle 上的變數
        bytes32 playerDrawHash = keccak256(
            abi.encodePacked(msg.sender, tokenId)
        );
        playerSnapshots[nextDraw][playerDrawHash] = PlaySnapshot(
            lotteryNumberToString,
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
