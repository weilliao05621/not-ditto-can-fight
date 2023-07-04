// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SetUpTest} from "test/setUp.t.sol";

contract Helper is SetUpTest {
    uint256 public constant MINT_PRICE = 0.001 ether;

    function userMintNewBornSingle(
        address user,
        uint256 fee,
        uint256 nftId
    ) public {
        vm.prank(user);
        notDittoCanFight.mintNotDitto{value: fee}(address(nft), nftId);
    }

    function userMintNewBornSingleWithInvalidAddress(
        address user,
        uint256 fee,
        address nftAddr,
        uint256 nftId
    ) public {
        vm.prank(user);
        notDittoCanFight.mintNotDitto{value: fee}(address(nftAddr), nftId);
    }

    function userMintNewBornBatch(
        address user,
        uint256 fee,
        uint256 amount,
        address[] memory nftAddresses,
        uint256[] memory nftIds
    ) public {
        vm.prank(user);
        notDittoCanFight.mintNotDittoBatch{value: fee}(
            amount,
            nftAddresses,
            nftIds
        );
    }

    function mintAllNewBorn() public {
        uint256 mintAmount = 3;
        uint256 mintFee = MINT_PRICE * mintAmount;
        (
            address[] memory nftAddresses,
            uint256[] memory nftIds
        ) = generateNftIdsData(0, mintAmount);

        userMintNewBornBatch(user1, mintFee, mintAmount, nftAddresses, nftIds);
        (nftAddresses, nftIds) = generateNftIdsData(3, mintAmount);
        userMintNewBornBatch(user2, mintFee, mintAmount, nftAddresses, nftIds);
        (nftAddresses, nftIds) = generateNftIdsData(6, mintAmount);
        userMintNewBornBatch(user3, mintFee, mintAmount, nftAddresses, nftIds);
        userMintNewBornSingle(user4, MINT_PRICE, 9);
    }

    function generateNftIdsData(
        uint256 startAt,
        uint256 amount
    ) public returns (address[] memory nftAddresses, uint256[] memory nftIds) {
        nftAddresses = new address[](3);
        nftIds = new uint256[](3);

        for (uint256 i = 0; i < amount; i++) {
            nftAddresses[i] = address(nft);
            nftIds[i] = i + startAt;
        }
    }

    function claimOfflineRewardWithPortion(
        uint256 times,
        uint256 notDittoId
    ) public {
        userMintNewBornSingle(user1, MINT_PRICE, 0);

        vm.startPrank(user1);
        for (uint256 i = 0; i < times; i++) {
            skip(0.125 days);
            notDittoCanFight.claimOfflineReward{value: RASIE_SUPPORT_FEE}(
                notDittoId
            );
        }
        vm.stopPrank();
    }
}