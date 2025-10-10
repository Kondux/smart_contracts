// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockKondux is ERC721Enumerable {

    // Mapping from token ID to DNA
    mapping(uint256 => uint256) public tokenDna;

    constructor() ERC721("MockKondux", "MKNDX") {
    }

    function safeMint(address to, uint256 dna) external returns (uint256) {
        uint256 _tokenId = totalSupply();
        _safeMint(to, _tokenId);
        tokenDna[_tokenId] = dna;
        return _tokenId; 
    }

    function grantRole(bytes32 role, address account) external {
    }
}
