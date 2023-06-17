// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAdmin {
    function admin() external view returns (address);
}

error GameAndControllShouldHaveSameAdmin();

contract Admin is IAdmin {
    address public immutable admin;

    constructor(address _admin) {
        if (Admin(msg.sender).admin() != _admin) {
            revert GameAndControllShouldHaveSameAdmin();
        }
        admin = _admin;
    }
}
