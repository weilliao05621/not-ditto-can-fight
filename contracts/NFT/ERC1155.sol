// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import "./IERC1155.sol";
import "./NotDittoConfig.sol";
import "../libs/Strings.sol";

// TODO: 要在特定功能上都增加檢查 ERC721 的權限

// 道具的部分再用 ERC1155、NotDittoCanFight 本身使用 ERC721A 比較適合
error NotOwnerOfTheNotDitto(uint256 id, address owner, address msgSender);
error VaultIsLocked();
error NotOnPendingLotteryList();
error PendingLotteryListIsFull();
error CanAccessToDrawWhenNotDittoFullyGrowTo30(uint256 level);
error InvalidLotteryNumberLength(string lotteryNumber);
error NotDittoIsUnhappyToMorphZeroAddress();
error InvalidLotteryNumber();

contract NotDittoCanFight is IERC165, ERC165, IERC1155, NotDittoConfig {
    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant RASIE_SUPPORT_FEE = (MINT_PRICE * 250) / 10000; // 2.5%

    uint256 public constant EXP_DECIMALS = 3;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _uris;

    mapping(uint256 => address) public owners;
    mapping(uint256 => NotDittoInfo) public notDittoInfos;
    mapping(uint256 => NotDittoSnapshot) public notDittoSnapshots;
    mapping(uint256 => NotDittoAsLottery) public notDittoAsLotteries;

    bool public vaultIsLock = true;

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function vault() public view returns (uint256 balance) {
        balance = address(this).balance;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external {}

    // TODO: 通信的機制: 可以轉讓 NFT，但會記錄 NFT 的原持有人有沒有授權
    // 多檢查一種 approval，這樣對方可以花錢借用 NotDitto、就不用大家都有 3 隻 NotDitto 才能打比賽
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {}

    function balanceOf(
        address _owner,
        uint256 _id
    ) external view returns (uint256) {}

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory) {}

    function setApprovalForAll(address _operator, bool _approved) external {}

    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {}

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

        notDittoSnapshots[tokenId] = NotDittoSnapshot(block.timestamp, 0, 0);
        notDittoAsLotteries[tokenId] = NotDittoAsLottery(0, "");

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
        string memory lotteryNumberToString = _toLotteryNumberString(
            lotteryNumber
        );

        NotDittoAsLottery memory _lottery = notDittoAsLotteries[tokenId];

        uint256 totalExp = notDittoSnapshots[tokenId].totalExp;

        uint256 currentLevel = _getCurrentLevel(totalExp);

        if (currentLevel != 30) {
            revert CanAccessToDrawWhenNotDittoFullyGrowTo30(currentLevel);
        }

        notDittoSnapshots[tokenId].totalExp = 0; // prevent suddenly draw again

        uint256 nextDraw = 1; // TODO: controll will fetch draw
        _lottery.draw = nextDraw;
        _lottery.lotteryNumber = lotteryNumberToString;

        notDittoAsLotteries[tokenId] = _lottery;
    }

    // === NotDitto Level === //
    function withdrawOfflineReward(uint256 id) external {
        if (msg.sender != owners[id]) {
            revert NotOwnerOfTheNotDitto(id, owners[id], msg.sender);
        }

        NotDittoSnapshot memory _snapshot = notDittoSnapshots[id];

        uint256 startAt = _snapshot.offlineRewardStartAt;
        uint256 effort = _snapshot.effort;
        uint256 level = _getCurrentLevel(_snapshot.totalExp);

        unchecked {
            uint256 duration = block.timestamp - startAt;

            uint256 portion = _getOfflineRewardPortion(duration);
            uint256 updatedTotalExp = _snapshot.totalExp +
                portion *
                _calcOfflineRewardPerDay(effort, level);

            notDittoSnapshots[id].offlineRewardStartAt = block.timestamp;
            notDittoSnapshots[id].totalExp = updatedTotalExp;
            notDittoSnapshots[id].effort = effort + 1;
        }
    }

    function _calcOfflineRewardPerDay(
        uint256 effort,
        uint256 level
    ) internal pure returns (uint256 reward) {
        uint256 baseRate = 4 * 10 ** EXP_DECIMALS;
        uint256 effortFactor = _getEffortFactorByLevel(level);
        bool unenoughEffort = effort < effortFactor * level;
        uint256 levelFactor = unenoughEffort
            ? ((level ** 2 * (10 - effortFactor)) / 10)
            : level ** 2;
        uint256 divFactor = 5;

        reward = (baseRate * levelFactor) / divFactor;
    }

    function _getOfflineRewardPortion(
        uint256 _duration
    ) internal pure returns (uint256 portion) {
        uint256 forDecimals = 10 ** EXP_DECIMALS;
        uint256 perDayBySecond = 86400;
        portion = (_duration * forDecimals) / perDayBySecond;
    }

    function _getEffortFactorByLevel(
        uint256 level
    ) public pure returns (uint256 effortFactor) {
        if (level < 4) effortFactor = 2;
        if (level < 8) effortFactor = 3;
        if (level < 13) effortFactor = 4;
        if (level < 19) effortFactor = 5;
        if (level < 26) effortFactor = 6;
        if (level < 30) effortFactor = 7;
    }

    // level curve is generated by the formula: ( 5000 * n^3 ) / 4 > 取 decinals 精度
    function _getCurrentLevel(
        uint256 totalExp
    ) public pure returns (uint256 level) {
        if (totalExp < 1250) level = 1;
        if (totalExp < 10000) level = 2;
        if (totalExp < 33750) level = 3;
        if (totalExp < 80000) level = 4;
        if (totalExp < 156250) level = 5;
        if (totalExp < 270000) level = 6;
        if (totalExp < 428750) level = 7;
        if (totalExp < 640000) level = 8;
        if (totalExp < 911250) level = 9;
        if (totalExp < 1215000) level = 10;
        if (totalExp < 1663750) level = 11;
        if (totalExp < 2160000) level = 12;
        if (totalExp < 2746250) level = 13;
        if (totalExp < 3430000) level = 14;
        if (totalExp < 4218750) level = 15;
        if (totalExp < 5120000) level = 16;
        if (totalExp < 6141250) level = 17;
        if (totalExp < 7290000) level = 18;
        if (totalExp < 8573750) level = 19;
        if (totalExp < 10000000) level = 20;
        if (totalExp < 11576250) level = 21;
        if (totalExp < 13310000) level = 22;
        if (totalExp < 15208750) level = 23;
        if (totalExp < 17280000) level = 24;
        if (totalExp < 19531250) level = 25;
        if (totalExp < 21970000) level = 26;
        if (totalExp < 24603750) level = 27;
        if (totalExp < 27440000) level = 28;
        if (totalExp < 30486250) level = 29;
        if (totalExp < 33750000) level = 30;
    }

    // === NotDitto Info === //
    // TODO: 還需要額外的 inteface 檢查
    function _replaceMorphNFT(
        uint256 tokenId,
        address nftAddr,
        uint256 nftTokenId
    ) external {
        if (msg.sender != owners[tokenId]) {
            revert NotOwnerOfTheNotDitto(tokenId, owners[tokenId], msg.sender);
        }

        if (nftAddr == address(0)) {
            revert NotDittoIsUnhappyToMorphZeroAddress();
        }

        if (nftTokenId == 0) {
            revert();
        }

        notDittoInfos[tokenId].nftAddress = nftAddr;
        notDittoInfos[tokenId].nftId = nftTokenId;
    }

    // TODO: 要寫出通用的 interface 檢查，利用該 interface 去檢查持有權
    function _checkOwnershipOfMorphNft(
        address nftAddress,
        uint256 nftTokenId,
        uint256 interfaceType
    ) private pure returns (bool isOwner) {}

    function _getElementalAttribute(
        string calldata _uri
    ) private pure returns (uint256 attribute) {
        attribute = uint8(bytes1(keccak256((abi.encodePacked(_uri))))) / 15;
    }

    function _toLotteryNumberString(
        uint256 num
    ) private pure returns (string memory buffer) {
        if (num > 9999) {
            revert InvalidLotteryNumber();
        }
        buffer = Strings.toString(num);
        if (num < 1000) {
            buffer = string.concat("0", buffer);
        } else if (num < 100) {
            buffer = string.concat("00", buffer);
        } else if (num < 10) {
            buffer = string.concat("000", buffer);
        }
    }
}
