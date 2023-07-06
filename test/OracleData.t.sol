// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {console} from "forge-std/console.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Helper} from "test/helper.t.sol";

// 紀念一下，成功拿到 mock 的 drawIndex:1 是 randomWords 是 [5, 6, 7, 7]、payment 100099205000000000

contract TestOracleData is Helper {
    uint256 public constant INIT_NEXT_DRAW_REWARD = 0.0001 ether;
    IERC20 LINK = IERC20(LINK_TOKEN_ADDRESS_OF_SEPOLIA);

    function test_getRandomWords() public {
        uint256 draw = 1;
        assertEq(notDittoCanFight.drawIndex(), draw);
        vm.prank(user1);
        notDittoCanFight.createNextDraw();
        assertEq(
            user1.balance,
            INIT_ETHER + INIT_NEXT_DRAW_REWARD,
            "ORACLE: INIT_NEXT_DRAW_REWARD"
        );
        uint256 requestId = notDittoCanFight.requestIdByDrawIndex(draw);
        (bool fulfilled, bool exists) = notDittoCanFight.requests(requestId);
        assertFalse(fulfilled, "ORACLE: SHOULD_NOT_BE_FULFILLED");
        assertTrue(exists, "ORACLE: SHOULD_EXIST");

        vrfCoordinatorV2Mock.fulfillRandomWords(
            requestId,
            address(vrfV2Wrapper)
        );

        vm.roll(block.number + REQUEST_CONFIRMATIONS);

        (fulfilled, ) = notDittoCanFight.requests(requestId);
        uint256[] memory randomWords = notDittoCanFight
            .getRadomWordsByRequestId(requestId);
        assertEq(randomWords.length, 4, "ORACLE: INVALID_RANDOM_WORDS_LENGTH");
        assertTrue(fulfilled, "ORACLE: SHOULD_BE_FULFILLED");
        assertEq(
            notDittoCanFight.drawIndex(),
            draw + 1,
            "ORACLE: INVALID_DRAW_INDEX"
        );
        assertGt(
            INIT_ERC20_BALANCE,
            LINK.balanceOf(address(notDittoCanFight)),
            "ORACLE: PAY_WITH_LINK"
        );
    }

    function test_revertWhenRequestNewDrawWithin7daysAgin() public {
        uint256 draw = 1;
        updateDraw(draw);
        vm.roll(block.number + REQUEST_CONFIRMATIONS);
        vm.expectRevert("ORACLE: can only create a new draw once a day");
        notDittoCanFight.createNextDraw();
    }
}
