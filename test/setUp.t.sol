// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol"; // coordinator
import "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol"; // link/eth
import "chainlink/contracts/src/v0.4/LinkToken.sol";
import "chainlink/contracts/src/v0.8/vrf/VRFV2Wrapper.sol";

import "contracts/test/FakeNFT.sol";
import "contracts/NotDittoCanFight.sol";

contract MockOracle {
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;
    uint96 _BASEFEE = 0.1 ether;
    uint96 _GASPRICELINK = 1 gwei;
    MockV3Aggregator mockV3Aggregator;
    uint8 _DECIMALS = 18;
    uint _INITIALANSWER = 0.003 ether;
    LinkToken link;
    VRFV2Wrapper vrfV2Wrapper;

    function _setOracleMock() public {
        // create coordinator first
        vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            _BASEFEE,
            _GASPRICELINK
        );
        // get link/eth price: 1 LINK = 0.003 native tokens
        mockV3Aggregator = new MockV3Aggregator(_DECIMALS, _INITIALANSWER);
        // a simple mock LINK
        link = new LinkToken();
        // creates a new subscription and adds itself to the newly created subscription
        vrfV2Wrapper = new VRFV2Wrapper(
            address(link),
            address(mockV3Aggregator),
            address(vrfCoordinatorV2Mock)
        );

        vrfV2Wrapper.setConfig(
            60000,
            52000,
            0, // no premium
            0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc, // 無法回推帶了多少，但因為是測試，所以先用
            4 // as the game config
        );
        // 預設需要付 10 ether 的 LINK
        vrfCoordinatorV2Mock.fundSubscription(1, 10 ether);
    }
}

contract SetUpTest is Test, MockOracle {
    address LINK_TOKEN_ADDRESS_OF_SEPOLIA =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address WRAPPER_V2_ADDRESS_OF_SEPOLIA =
        0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint256 constant NOT_DITTO_ID = 0;
    FakeERC721 nft;
    NotDittoCanFight notDittoCanFight;

    address user1;
    address user2;
    address user3;
    address user4;

    function setUp() public virtual {
        nft = new FakeERC721();

        notDittoCanFight = new NotDittoCanFight(
            address(link),
            address(vrfV2Wrapper)
        );

        address[] memory tokens = new address[](1);
        address[] memory tos = new address[](1);
        tokens[0] = address(link);
        tos[0] = address(notDittoCanFight);
        _initAllBalances(tokens, tos);

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

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

        notDittoCanFight = new NotDittoCanFight(
            LINK_TOKEN_ADDRESS_OF_SEPOLIA,
            WRAPPER_V2_ADDRESS_OF_SEPOLIA
        );

        address[] memory tokens = new address[](1);
        tokens[0] = LINK_TOKEN_ADDRESS_OF_SEPOLIA;

        address[] memory tos = new address[](1);
        tos[0] = address(notDittoCanFight);

        _initAllBalances(tokens, tos);
    }

    function _initEther() public {
        // assign 10 ETHER to users for minting
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
    }

    function _initAllBalances(
        address[] memory tokens,
        address[] memory tos
    ) internal {
        // assign 100 LINK to contract
        for (uint256 i = 0; i < tokens.length; i++) {
            deal(tokens[i], tos[i], 100 ether);
        }
        _initEther();
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

        // extra mint for testing upper limit
        nft.mint(user, 12);
    }
}
