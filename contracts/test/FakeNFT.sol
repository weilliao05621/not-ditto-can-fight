// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract FakeERC721 is ERC721("Fake ERC721","F721") {
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
