// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockFoundersPass is ERC721 {
    uint256 public totalSupplyCount;

    constructor() ERC721("MockFoundersPass", "MFP") {
    }

    function safeMint(address to) external {
        uint256 _tokenId = totalSupplyCount++;
        _safeMint(to, _tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return totalSupplyCount;
    }
}
