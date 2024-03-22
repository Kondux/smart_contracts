// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KonduxERC721Founders is Ownable, ERC721Enumerable {
    uint256 private counter = 0;

    constructor() ERC721("KonduxERC721Founders", "KonduxERC721Founders") Ownable(msg.sender) {
        faucet();
    }

    function faucet() public {
        counter++;
        _mint(msg.sender, counter);
    }

    function burn(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "KonduxERC721Founders: caller is not the owner");
        _transfer(msg.sender, address(0x2345678901234567890123456789012345678901), tokenId);
    }
}
