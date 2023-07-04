// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NFT/NotDittoAndItems.sol";
import {LotteryAndFight} from "./Oracle/RandomNumber.sol";

import "./libs/Level.sol";
import "./libs/Lottery.sol";

error VaultIsLocked();
error CanAccessToDrawWhenNotDittoFullyGrowTo30(uint256 level);

contract NotDittoCanFight is NotDittoAndItems, LotteryAndFight {
    struct PlaySnapshot {
        uint256[4] lotteryNumber;
        uint256 effort;
        bool engagedLottery;
    }

    uint256 public constant EXCEED_DAYS_MAKE_NOT_DITTO_UNATTENDED = 7;
    uint256 public constant INIT_NEXT_DRAW_REWARD = 0.0001 ether;
    // draw (requestId) => lotteryNumberHashByOwner => PlaySnapshot
    mapping(uint256 => mapping(bytes32 => PlaySnapshot)) public playerSnapshots;
    // 確認每個 address 擁有的 notDitto 是參與哪一期的 draw
    mapping(address => uint256[3]) public engagedLotteryList;

    uint256 creatingNewDraw = 1;

    modifier noReentry() {
        require(creatingNewDraw == 1, "Not Allow Reentrancy");
        creatingNewDraw = 2;
        _;
        creatingNewDraw = 1;
    }

    constructor(
        address _link,
        address _vrf_v2_wrapper
    ) payable LotteryAndFight(_link, _vrf_v2_wrapper) {}

    // === NotDitto Lottery === //
    function withdrawLotteryPrize(uint256 draw) external noReentry {
        if (vaultIsLocked()) {
            revert VaultIsLocked();
        }

        uint256[3] memory _engagedLotteryList = engagedLotteryList[msg.sender];
        uint256 tickets = _engagedLotteryList.length;

        if (tickets == 0) {
            revert();
        }

        uint256 reward;

        for (uint256 i = 0; i < tickets; ) {
            uint256 lotteryIndex = tickets - 1;
            uint256 notDittoIndex = _engagedLotteryList[lotteryIndex];

            bytes32 playerDrawHash = keccak256(
                abi.encodePacked(msg.sender, notDittoIndex)
            );

            PlaySnapshot memory playerSnapshot = playerSnapshots[draw][
                playerDrawHash
            ];
            require(playerSnapshot.engagedLottery);
            playerSnapshots[draw][playerDrawHash].engagedLottery = false;
            delete _engagedLotteryList[lotteryIndex];

            uint256 factor = Lottery._checkLotteryPrize(
                requests[draw].randomWords,
                playerSnapshot.lotteryNumber
            );

            uint256 effortRefund = playerSnapshot.effort * RASIE_SUPPORT_FEE;
            reward += Lottery._calcPrizeWithFactor(effortRefund, factor);
        }

        engagedLotteryList[msg.sender] = _engagedLotteryList;
        payable(msg.sender).transfer(reward); // TODO: 改用 WETH 來進行
    }

    function vaultIsLocked() internal view returns (bool locked) {
        locked = address(this).balance <= 0.5 ether;
    }

    function engageInLottery(
        uint256 tokenId,
        uint256[4] calldata lotteryNumber
    ) external {
        if (vaultIsLocked()) {
            revert VaultIsLocked();
        }

        if (!checkIsNotDittoOwner(tokenId)) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NOT_DITTO)
            );
        }

        NotDittoSnapshot memory _notDittoSnapshot = notDittoSnapshots[tokenId];
        uint256 totalExp = _notDittoSnapshot.totalExp;
        uint256 currentLevel = Level._getCurrentLevel(totalExp);

        if (currentLevel != 30) {
            revert CanAccessToDrawWhenNotDittoFullyGrowTo30(currentLevel);
        }

        _burnNotDitto(tokenId, false);

        bytes32 playerDrawHash = keccak256(
            abi.encodePacked(msg.sender, tokenId)
        );
        uint256 _lastRequestId = lastRequestId;
        uint256 draw = requests[_lastRequestId].fulfilled
            ? _lastRequestId + 1
            : _lastRequestId;

        playerSnapshots[draw][playerDrawHash] = PlaySnapshot(
            lotteryNumber,
            _notDittoSnapshot.effort,
            true
        );

        engagedLotteryList[msg.sender][
            engagedLotteryList[msg.sender].length
        ] = tokenId;
    }

    function createNextDraw() public noReentry {
        requestNewRandomNum();
        // TODO: assign payment if one has create new draw
        payable(msg.sender).transfer(INIT_NEXT_DRAW_REWARD);
    }

    // 讓遊戲能繼續的機制：確實有可能有人把 NFT 賣了，卻忘記自己有 mint 過 NotDitto
    function takeUnattendedNotDittoToOrphanage(uint256 id) public noReentry {
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
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NOT_DITTO)
            );
        }
        // TODO: 如果是 0 等要提領，會把 allowTransfered 調成 false
        NotDittoSnapshot memory _snapshot = notDittoSnapshots[tokenId];

        uint256 startAt = _snapshot.offlineRewardStartAt;
        uint256 effort = _snapshot.effort;
        uint256 level = Level._getCurrentLevel(_snapshot.totalExp);

        unchecked {
            uint256 duration = block.timestamp - startAt;

            uint256 portion = Level._getOfflineRewardPortion(duration);
            // prettier-ignore
            uint256 expPerPortion = Level._calcOfflineRewardPerDay(effort, level);
            uint256 rawRewardExp = portion * expPerPortion;
            // since both portion and effort are mul by decimals, need to div by decimals
            uint256 rewardExp = rawRewardExp / (10 ** Level.EXP_DECIMALS);
            uint256 updatedTotalExp = _snapshot.totalExp + rewardExp;

            notDittoSnapshots[tokenId].offlineRewardStartAt = block.timestamp;
            notDittoSnapshots[tokenId].totalExp = updatedTotalExp;
            notDittoSnapshots[tokenId].effort = effort + 1;
        }
    }
}
