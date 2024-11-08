// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockKondux is ERC721 {
    uint256 public totalSupplyCount;

    constructor() ERC721("MockKondux", "MKNDX") {
    }

    function safeMint(address to, uint256 dna) external returns (uint256) {
        uint256 _tokenId = totalSupplyCount++;
        _safeMint(to, _tokenId);
        return _tokenId; 
    }

    function totalSupply() public view returns (uint256) {
        return totalSupplyCount;
    }

    function grantRole(bytes32 role, address account) external {
    }
}
