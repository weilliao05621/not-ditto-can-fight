// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {ErrorConfig} from "contracts/NFT/ErrorConfig.sol";
import {MintHelper} from "test/MintNotDitto/helper.t.sol";

contract TestMintNotDitto is MintHelper, ErrorConfig {
    function setUp() public override {
        super.setUp();
        // forkFromSepolia();
        _initEther();
    }

    function test_mintNotDittoSigle() public {
        uint256 totalSupplyBefore = notDittoCanFight.totalSupplies(
            NOT_DITTO_ID
        );
        uint256 balanceBefore = notDittoCanFight.balanceOf(user1, NOT_DITTO_ID);
        uint256 nftId;
        address nftAddr;
        address owner;

        (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(
            totalSupplyBefore
        );

        assertEq(owner, address(0), "MINT: INIT_OWNERSHIP");

        userMintNewBornSingle(user1, MINT_PRICE, 0);

        uint256 totalSupplyAfter = notDittoCanFight.totalSupplies(NOT_DITTO_ID);
        uint256 balanceAfter = notDittoCanFight.balanceOf(user1, NOT_DITTO_ID);
        (nftId, nftAddr, , owner) = notDittoCanFight.notDittoInfos(
            totalSupplyAfter
        );
        bytes32 nftInfoHash = keccak256(abi.encodePacked(nftAddr, nftId));

        assertTrue(
            notDittoCanFight.morphedNftHash(nftInfoHash),
            "BATCH-MINT: MORPHED_NFT_HASH"
        );
        assertEq(nftId, 0, "MINT: MINTED_INDEX");
        assertEq(totalSupplyAfter - totalSupplyBefore, 1, "MINT: TOTAL_SUPPLY");
        assertEq(balanceAfter - balanceBefore, 1, "MINT: BALANCE");
        assertEq(owner, user1, "MINT: MINTED_OWNERSHIP");
        assertEq(nftAddr, address(nft), "MINT: MINTED_NFT_ADDRESS");
    }

    

    function test_validToPayOverMintFee() public {
        uint256 higherPrice = MINT_PRICE + MINT_PRICE / 10;
        userMintNewBornSingle(user1, higherPrice, 0);
    }

    // record: 修改 mintFee 驗證，至少每隻 notDitto 都要花 0.001 ether
    function test_revertWhenPayUnderMintFee() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.WRONG_MINT_PRICE)
            )
        );
        uint256 lowerPrice = MINT_PRICE - MINT_PRICE / 10;
        userMintNewBornSingle(user1, lowerPrice, 0);
    }

    // record: 忘記阻止每個人能 mint 的數量
    function test_revertWhenExceedMaxMintAmountPerAddress() public {
        uint256 mintAmount = 3;
        uint256 mintFee = MINT_PRICE * mintAmount;
        (
            address[] memory nftAddresses,
            uint256[] memory nftIds
        ) = generateNftIdsData(0, mintAmount);

        userMintNewBornBatch(user1, mintFee, mintAmount, nftAddresses, nftIds);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.ALL_NOT_DITTO_HAS_PARENTS)
            )
        );
        userMintNewBornSingle(user1, MINT_PRICE, 12);
    }

    function test_revertWhenReachTotalSupplyOfNotDitto() public {
        mintAllNewBorn();
        assertEq(
            notDittoCanFight.totalSupplies(NOT_DITTO_ID),
            notDittoCanFight.MAX_NOT_DITTO_SUPPLY(),
            "MINT: TOTAL_SUPPLY"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.ALL_NOT_DITTO_HAS_PARENTS)
            )
        );
        userMintNewBornSingle(user4, MINT_PRICE, 10);
    }

    function test_revertWhenMintWithExistedMorphedNft() public {
        userMintNewBornSingle(user1, MINT_PRICE, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.NOT_DITTO_IS_UNHAPPY_TO_MORPH_EXISTED_NFT)
            )
        );
        userMintNewBornSingle(user1, MINT_PRICE, 0);
    }

    // error: 發現 mint 的缺少 revert > 不是 owner of NFT 的判斷
    function test_revertWhenMintWithoutOwnershipOfNft() public {
        uint256 nftId = 3;
        assertEq(nft.ownerOf(nftId), user2, "MINT: OWNERSHIP_TRANSFERED");
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NFT)
            )
        );
        userMintNewBornSingle(user1, MINT_PRICE, nftId);
    }

    function test_revertWhenZeroAddressGivenAsNftAddress() public {
        address zAddr = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(
                    ErrorNotDitto.NOT_DITTO_IS_UNHAPPY_TO_MORPH_ZERO_ADDRESS
                )
            )
        );
        userMintNewBornSingleWithInvalidAddress(user1, MINT_PRICE, zAddr, 0);
    }

    function test_revertWhenGameAddressGivenAsNftAddress() public {
        address game = address(notDittoCanFight);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorFromInteractWithNotDitto.selector,
                uint256(ErrorNotDitto.NOT_DITTO_IS_UNHAPPY_TO_MORPH_ITSELF)
            )
        );
        userMintNewBornSingleWithInvalidAddress(user1, MINT_PRICE, game, 0);
    }

    function test_revertWhenInvalidAddressGivenAsNftAddress() public {
        vm.expectRevert();
        userMintNewBornSingleWithInvalidAddress(
            user1,
            MINT_PRICE,
            address(this),
            0
        );
    }

    function test_revertWhenEOAGivenAsNftAddress() public {
        vm.expectRevert();
        userMintNewBornSingleWithInvalidAddress(user1, MINT_PRICE, user1, 0);
    }
}
