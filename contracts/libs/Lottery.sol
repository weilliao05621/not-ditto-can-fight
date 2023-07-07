// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Lottery {
    function _checkLotteryPrize(
        uint256[] memory drawNumber,
        uint256[4] memory lotteryNumber
    ) public pure returns (uint256) {
        uint256 prizeFactor;

        for (uint256 i = 0; i < lotteryNumber.length; ) {
            if (drawNumber[i] == lotteryNumber[i]) {
                prizeFactor += 1;
            }
            // prettier-ignore
            unchecked { ++i; }
        }

        return prizeFactor;
    }

    function _calcPrizeWithFactor(
        uint256 _reward,
        uint256 _factor
    ) public pure returns (uint256) {
        if (_factor == 1) return _reward;
        if (_factor == 2) return (_reward * 12) / 10;
        if (_factor == 3) return _reward * 5;
        if (_factor == 4) return _reward * 10;
        return (_reward * 8) / 10;
    }
}
