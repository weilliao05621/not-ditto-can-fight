// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "ERC721A/IERC721A.sol";
import "./Admin.sol";

error NotGameContractCalling();
error NotAllowNotDittoToBeSelfMinted();

contract Controller is Admin {
    address private _gameContract;
    address private _notDittoContract;

    mapping(bytes32 => bool) public isNftHasMintedItem;

    uint256 public constant MAX_NOT_DITTO_SUPPLY = 1000;
    uint256 public constant MAX_NOT_DITTO_SUPPLY_PER_ADDRESS = 3;

    constructor(
        address _admin,
        address gameContract_,
        address notDittoContract_
    ) Admin(_admin) {
        initialize(gameContract_, notDittoContract_);
    }

    function initialize(
        address gameContract_,
        address notDittoContract_
    ) internal {
        require(
            _gameContract == address(0) && _notDittoContract == address(0),
            "Controller: already initialized"
        );
        require(
            _gameContract != address(this),
            "Controller: game contract can't be controller contract itself"
        );
        require(
            _notDittoContract != address(this),
            "Controller: not ditto contract can't be controller contract itself"
        );

        _gameContract = gameContract_;
        _notDittoContract = notDittoContract_;
    }

    function checkIsOwnerOfTokenId(
        address player,
        address nftAddr,
        uint256 tokenId
    ) external view returns (bool isOwner) {
        if (nftAddr == _notDittoContract) {
            revert NotAllowNotDittoToBeSelfMinted();
        }

        bytes memory payload = abi.encodeWithSignature(
            "ownerOf(uint256)",
            tokenId
        );
        (bool success, bytes memory rawOwner) = nftAddr.staticcall(payload);
        require(success, "Controller: ownerOf call failed");
        isOwner = abi.decode(rawOwner, (address)) == player;
    }

    function setNftHasMintedItem(address nftAddr, uint256 tokenId) external {
        if (msg.sender != _gameContract) {
            revert NotGameContractCalling();
        }
        isNftHasMintedItem[
            keccak256(abi.encodePacked(nftAddr, tokenId))
        ] = true;
    }

    function checkHasReachedLimitMintedAmount(
        address owner
    ) external view returns (bool hasReached) {
        uint256 balance = IERC721A(_notDittoContract).balanceOf(owner);
        hasReached = balance >= MAX_NOT_DITTO_SUPPLY_PER_ADDRESS;
    }

    function checkHasReachedMaxSupply()
        external
        view
        returns (bool hasReached)
    {
        uint256 totalSupply = IERC721A(_notDittoContract).totalSupply();
        hasReached = totalSupply >= MAX_NOT_DITTO_SUPPLY;
    }
}
