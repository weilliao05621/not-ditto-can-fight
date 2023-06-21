// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Math.sol";

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol

error InvalidLotteryNumber();

// [advanced]: 理解為什麼 opcode 這樣運作
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) public pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function toLotteryNumberString(
        uint256 num
    ) public pure returns (string memory buffer) {
        if (num > 9999) {
            revert InvalidLotteryNumber();
        }
        buffer = toString(num);
        if (num < 1000) {
            buffer = string.concat("0", buffer);
        } else if (num < 100) {
            buffer = string.concat("00", buffer);
        } else if (num < 10) {
            buffer = string.concat("000", buffer);
        }
    }
}
