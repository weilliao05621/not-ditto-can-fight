// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./NFT/NotDittoAndItems.sol";
import {LotteryAndFight} from "./Oracle/RandomNumber.sol";

import "./libs/Level.sol";
import "./libs/Lottery.sol";

error VaultIsLocked();

contract NotDittoCanFight is NotDittoAndItems, LotteryAndFight {
    struct PlaySnapshot {
        uint256[4] lotteryNumber;
        uint256 effort;
        bool engagedLottery;
    }

    uint256 public constant EXCEED_DAYS_MAKE_NOT_DITTO_UNATTENDED = 7;
    uint256 public constant INIT_NEXT_DRAW_REWARD = 0.0001 ether;
    uint256 public constant TAKE_CARE_NOT_DITTO_REWARD = MINT_PRICE / 10;
    // draw (drawIndex) => lotteryNumberHashByOwner => PlaySnapshot
    mapping(uint256 => mapping(bytes32 => PlaySnapshot)) public playerSnapshots;
    // owner => drawIndex(3)
    mapping(address => uint256[MAX_NOT_DITTO_SUPPLY_PER_ADDRESS])
        public engagedLotteryList;
    // owner => notDittoId(3)
    mapping(address => uint256[MAX_NOT_DITTO_SUPPLY_PER_ADDRESS])
        public engagedDrawByNotDittoIds;

    constructor(
        address _link,
        address _vrf_v2_wrapper
    ) payable LotteryAndFight(_link, _vrf_v2_wrapper) {}

    // === NotDitto Lottery === //
    function claimLotteryPrize() external {
        if (address(this).balance <= 0.5 ether) {
            revert VaultIsLocked();
        }

        uint256[3] memory _engagedLotteryList = engagedLotteryList[msg.sender];
        uint256[3] memory _engagedDrawByNotDittoIds = engagedDrawByNotDittoIds[
            msg.sender
        ];

        uint256 tickets;

        for (uint256 i = 0; i < _engagedLotteryList.length; ) {
            unchecked {
                tickets = _engagedLotteryList[i] == 0 ? tickets : tickets + 1;
                ++i;
            }
        }

        if (tickets == 0) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.HAS_NO_ENGAGED_TICKETS)
            );
        }

        uint256 reward;

        // 每次領獎都是全部 ticket 一次領完
        for (uint256 i = 0; i < tickets; ) {
            // fix: index should be dynamic to ensure every ticket is used
            uint256 lotteryIndex = tickets - i - 1;
            uint256 drawIndex = _engagedLotteryList[lotteryIndex];
            uint256 notDittoIndex = _engagedDrawByNotDittoIds[lotteryIndex];

            // 利用 owner + notDittoIndex 來算出特別的 lotteryNumberHash
            bytes32 playerDrawHash = keccak256(
                abi.encodePacked(msg.sender, notDittoIndex)
            );

            PlaySnapshot memory _playerSnapshot = playerSnapshots[drawIndex][
                playerDrawHash
            ];

            bool engaged = _playerSnapshot.engagedLottery;

            if (!engaged) {
                revert ErrorFromInteractWithNotDitto(
                    uint256(
                        ErrorNotDitto.THIS_TICKET_IS_NOT_COMFIRMED_TO_ENGAGE
                    )
                );
            }

            // backing to false when player claim prize is enough, since engaging in new lottery draw will re-assign all new values
            playerSnapshots[drawIndex][playerDrawHash].engagedLottery = false;

            unchecked {
                uint256 _requestIdByDrawIndex = requestIdByDrawIndex[drawIndex];
                uint256 factor = Lottery._checkLotteryPrize(
                    requests[_requestIdByDrawIndex].randomWords,
                    _playerSnapshot.lotteryNumber
                );
                uint256 effortRefund = _playerSnapshot.effort *
                    RASIE_SUPPORT_FEE;
                reward += Lottery._calcPrizeWithFactor(effortRefund, factor);
                ++i;
            }
        }

        delete engagedLotteryList[msg.sender];
        delete engagedDrawByNotDittoIds[msg.sender];

        payable(msg.sender).transfer(reward);
    }

    function engageInLottery(
        uint256 tokenId,
        uint256[4] memory lotteryNumber
    ) external {
        if (address(this).balance <= 0.5 ether) {
            revert VaultIsLocked();
        }

        if (msg.sender != ownerOf(tokenId)) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NOT_DITTO)
            );
        }

        NotDittoSnapshot memory _notDittoSnapshot = notDittoSnapshots[tokenId];
        uint256 totalExp = _notDittoSnapshot.totalExp;
        uint256 currentLevel = Level._getCurrentLevel(totalExp);

        if (currentLevel < 30) {
            revert ErrorFromInteractWithNotDitto(
                uint256(
                    ErrorNotDitto.SHOULD_ACCESS_TO_DRAW_WITH_MAX_LV_NOT_DITTO
                )
            );
        }

        burnNotDitto(tokenId, false);
        // 因為有可能 adopt 同一個 tokenId 的 NotDitto，所以用 owner + tokenId
        bytes32 playerDrawHash = keccak256(
            abi.encodePacked(msg.sender, tokenId)
        );

        if (playerSnapshots[drawIndex][playerDrawHash].engagedLottery) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.ALREADY_ENGAGED_IN_THIS_DRAW)
            );
        }

        // 直接參加還未開獎的那一期
        playerSnapshots[drawIndex][playerDrawHash] = PlaySnapshot(
            lotteryNumber,
            _notDittoSnapshot.effort,
            true
        );

        uint256[3] memory _engagedLotteryList = engagedLotteryList[msg.sender];

        // fixed array 會有起始長度，避免出現 index out of bounds
        uint256 engagedTickets = _engagedLotteryList.length;
        uint256 ticketIndex;
        bool noTicketAllowed = false;
        for (uint256 i = 0; i < engagedTickets; i++) {
            if (_engagedLotteryList[i] == 0) {
                ticketIndex = i;
                break;
            } else {
                noTicketAllowed = i == 2;
            }
        }

        require(!noTicketAllowed);

        engagedLotteryList[msg.sender][ticketIndex] = drawIndex;
        engagedDrawByNotDittoIds[msg.sender][ticketIndex] = tokenId;
    }

    // === NotDitto Level === //
    function claimOfflineReward(uint256 tokenId) external payable {
        if (msg.sender != ownerOf(tokenId)) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NOT_DITTO)
            );
        }

        if (msg.value < RASIE_SUPPORT_FEE) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_ENOUGH_RAISE_SUPPORT_FEE)
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

    function createNextDraw() external {
        // TODO: exchange ETH for LINK to pay for Chainlink VRF
        requestNewRandomNum();
        payable(msg.sender).transfer(INIT_NEXT_DRAW_REWARD);
    }

    // 讓遊戲能繼續的機制：確實有可能有人把 NFT 賣了，卻忘記自己有 mint 過 NotDitto
    // 如果已經有參加抽獎，則 NotDitto 也已經變成 orphan
    function takeUnattendedNotDittoToOrphanage(uint256 id) external {
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

        burnNotDitto(id, true);
        // TODO: assign payment if one has took care of our NotDitto
        payable(msg.sender).transfer(TAKE_CARE_NOT_DITTO_REWARD);
    }

    // getter for fixed array
    function getLotteryNumberByEngagedNumber(
        uint256 draw,
        address owner,
        uint256 tokenId
    ) public view returns (uint256[4] memory) {
        bytes32 playerHash = keccak256(abi.encodePacked(owner, tokenId));
        return playerSnapshots[draw][playerHash].lotteryNumber;
    }

    function getEngagedLotteryList(
        address owner
    ) public view returns (uint256[3] memory) {
        return engagedLotteryList[owner];
    }

    function getEngagedDrawByNotDittoIds(
        address owner
    ) public view returns (uint256[3] memory) {
        return engagedDrawByNotDittoIds[owner];
    }
}
