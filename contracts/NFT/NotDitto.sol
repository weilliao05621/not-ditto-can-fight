// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "ERC721A/ERC721A.sol";
import "../interfaces/INotDitto.sol";
import "../Admin.sol";

error OnlyGameContractCanCall();

contract NotDitto is INotDitto, Admin, ERC721A("Not Ditto", "NDCF") {
    address private _gameContract;

    constructor(address _admin, address gameContract_) Admin(_admin) {
        initialize(gameContract_);
    }

    function mint(uint256 amount) external {
        if (msg.sender != _gameContract) {
            revert OnlyGameContractCanCall();
        }
        _mint(msg.sender, amount);
    }

    function initialize(address gameContract_) internal {
        require(_gameContract == address(0), "NotDitto: already initialized");
        require(
            _gameContract != address(this),
            "NotDitto: game contract can't be not ditto contract itself"
        );

        _gameContract = gameContract_;
    }
}
