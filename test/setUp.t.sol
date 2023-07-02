// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/test/FakeNFT.sol";
import "../contracts/NotDittoCanFight.sol";

contract SetUpTest is Test {
    address LINK_TOKEN_ADDRESS_OF_SEPOLIA =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address WRAPPER_V2_ADDRESS_OF_SEPOLIA =
        0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    FakeERC721 nft;
    NotDittoCanFight notDittoCanFight;
    address deployer;
    address user1;
    address user2;
    address user3;
    address user4;

    function setUp() public {
        nft = new FakeERC721();
        notDittoCanFight = new NotDittoCanFight(
            LINK_TOKEN_ADDRESS_OF_SEPOLIA,
            WRAPPER_V2_ADDRESS_OF_SEPOLIA
        );

        deployer = makeAddr("deployer");

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        vm.label(deployer, "deployer");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");
        vm.label(user4, "user4");

        _mintFakeERC721();
    }

    function forkFromSepolia() public {
        string memory SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        uint256 forkId = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(forkId);

        address[] memory tokens = new address[](1);
        tokens[0] = LINK_TOKEN_ADDRESS_OF_SEPOLIA;

        address[] memory tos = new address[](1);
        tos[0] = address(notDittoCanFight);

        _initBalances(tokens, tos);
    }

    function _initBalances(
        address[] memory tokens,
        address[] memory tos
    ) internal {
        // assign 100 LINK to contract
        for (uint256 i = 0; i < tokens.length; i++) {
            deal(tokens[i], tos[i], 100 ether);
        }

        // assign 10 ETHER to users for minting
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
    }

    function _mintFakeERC721() internal {
        uint256 mintAmount = 12;
        address user;
        for (uint256 i = 0; i < mintAmount; i++) {
            if (i < 3) user = user1;
            if (3 <= i && i < 6) user = user2;
            if (6 <= i && i < 9) user = user3;
            if (9 <= i && i < 12) user = user4;
            nft.mint(user, i);
        }
    }
}
