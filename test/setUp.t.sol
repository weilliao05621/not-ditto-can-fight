// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol"; // coordinator
import "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol"; // link/eth
import "chainlink/contracts/src/v0.8/vrf/VRFV2Wrapper.sol";

import "contracts/test/FakeNFT.sol";
import "contracts/NotDittoCanFight.sol";

contract MockOracle {
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;
    uint96 _BASEFEE = 0.1 ether;
    uint96 _GASPRICELINK = 1 gwei;
    MockV3Aggregator mockV3Aggregator;
    VRFV2Wrapper vrfV2Wrapper;
    uint16 public constant REQUEST_CONFIRMATIONS = 10;

    function _setOracleMock(address _link) public {
        // create coordinator first
        vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            _BASEFEE,
            _GASPRICELINK
        );
        // get link/eth price: 1 LINK = 0.003 native tokens
        mockV3Aggregator = new MockV3Aggregator(18, 0.003 ether);

        // creates a new subscription and adds itself to the newly created subscription
        vrfV2Wrapper = new VRFV2Wrapper(
            _link,
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
    // address WRAPPER_V2_ADDRESS_OF_SEPOLIA =
    //     0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint256 constant NOT_DITTO_ID = 0;
    FakeERC721 nft;
    NotDittoCanFight notDittoCanFight;

    uint256 constant INIT_ERC20_BALANCE = 100 ether;
    uint256 constant INIT_ETHER = 10 ether;

    address user1;
    address user2;
    address user3;
    address user4;

    function setUp() public virtual {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");
        vm.label(user4, "user4");

        nft = new FakeERC721();
        _mintFakeERC721();
    }

    function forkFromSepolia() public {
        string memory SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        uint256 forkId = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(forkId);

        _setOracleMock(LINK_TOKEN_ADDRESS_OF_SEPOLIA);
        notDittoCanFight = new NotDittoCanFight(
            address(LINK_TOKEN_ADDRESS_OF_SEPOLIA),
            address(vrfV2Wrapper)
        );

        address[] memory tokens = new address[](1);
        tokens[0] = LINK_TOKEN_ADDRESS_OF_SEPOLIA;

        address[] memory tos = new address[](1);
        tos[0] = address(notDittoCanFight);

        _initAllBalances(tokens, tos);
    }

    function localTesting() public {
        notDittoCanFight = new NotDittoCanFight(
            address(0),
            address(0)
        );
        _initEther();
    }

    function _initEther() public {
        // assign 10 ETHER to users for minting
        vm.deal(user1, INIT_ETHER);
        vm.deal(user2, INIT_ETHER);
        vm.deal(user3, INIT_ETHER);
        vm.deal(user4, INIT_ETHER);
        vm.deal(address(notDittoCanFight), INIT_ETHER);
    }

    function _initAllBalances(
        address[] memory tokens,
        address[] memory tos
    ) internal {
        // assign 100 LINK to contract
        for (uint256 i = 0; i < tokens.length; i++) {
            deal(tokens[i], tos[i], INIT_ERC20_BALANCE);
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
