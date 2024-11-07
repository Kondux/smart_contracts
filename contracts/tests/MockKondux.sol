// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockKondux is ERC721 {
    uint256 public totalSupplyCount;

    constructor() ERC721("MockKondux", "MKNDX") {
    }

    function safeMint(address to, uint256 tokenId) external returns (uint256) {
        _safeMint(to, tokenId);
        totalSupplyCount += 1;
        return tokenId;
    }

    function totalSupply() public view returns (uint256) {
        return totalSupplyCount;
    }

    function grantRole(bytes32 role, address account) external {
    }
}
