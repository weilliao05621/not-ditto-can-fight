// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

// TODO: For testing propose, will need a MOCK_COORDINATOR which has the ownership to make the fullfil completed
// Sepolia （用 testnet 去做 fork 的測試）: LINK 0x779877A7B0D9E8603169DdbD7836e478b4624789 || WRAPPER V2 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46
// TODO: Will use random number to create batches for fighting in the future

contract LotteryAndFight is VRFV2WrapperConsumerBase {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    uint32 public constant CALLBACK_GAS_LIMITATION = 1_000_000;
    uint16 public constant REQUEST_CONFIRMATIONS = 10;
    uint32 public constant NUM_WORDS = 4;
    uint176 public lastRequestId = 1;
    uint256 public lastRequestTimestamp; // 用來確保每次開獎都至少間隔一定天數
    // requestId => RequestStatus
    mapping(uint256 => RequestStatus) public requests;

    constructor(
        address _link,
        address _vrf_v2_wrapper
    ) VRFV2WrapperConsumerBase(_link, _vrf_v2_wrapper) {}

    // handles the VRF response
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(
            requests[requestId].exists,
            "requestId does not exist or has already been fulfilled"
        );

        require(randomWords.length == NUM_WORDS, "wrong number of randomWords");
        requests[requestId].fulfilled = true;
        requests[requestId].randomWords = randomWords;

        emit RequestFulfilled(requestId, randomWords);
    }

    function requestNewRandomNum() internal {
        require(
            block.timestamp - lastRequestTimestamp >= 1 days,
            "ORACLE: can only create a new draw once a day"
        );
        lastRequestTimestamp = block.timestamp;

        uint176 _lastRequestId = lastRequestId;
        requests[_lastRequestId] = RequestStatus({
            fulfilled: false,
            exists: true,
            randomWords: new uint256[](0)
        });
        _lastRequestId = _lastRequestId + 1;
        lastRequestId = _lastRequestId;

        requestRandomness(
            CALLBACK_GAS_LIMITATION,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS
        );

        emit RequestSent(_lastRequestId, NUM_WORDS);
    }
}
