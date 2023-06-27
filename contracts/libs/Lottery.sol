// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Lottery {
    function _checkLotteryPrize(
        uint256[4] memory drawNumber,
        uint256[4] memory lotteryNumber
    ) public pure returns (uint256 prizeFactor) {
        for (uint256 i = 0; i < lotteryNumber.length; i++) {
            if (drawNumber[i] == lotteryNumber[i]) {
                prizeFactor += 1;
            }
        }
    }

    function _calcPrizeWithFactor(
        uint256 _reward,
        uint256 _factor
    ) public pure returns (uint256 reward) {
        if (_factor == 1) reward = _reward;
        if (_factor == 2) reward = (_reward * 12) / 10;
        if (_factor == 3) reward = _reward * 2;
        if (_factor == 4) reward = _reward * 5;
    }
}
