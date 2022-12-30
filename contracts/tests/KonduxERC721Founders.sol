// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KonduxERC721Founders is Ownable, ERC721Enumerable {
    uint256 private counter = 0;

    constructor() ERC721("KonduxERC721Founders", "KonduxERC721Founders") {
        faucet();
    }

    function faucet() public {
        counter++;
        _mint(msg.sender, counter);
    }
}
