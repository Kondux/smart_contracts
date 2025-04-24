// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KonduxERC721kNFT is Ownable, ERC721Enumerable, ERC721Burnable {
    uint256 private counter = 0;

    constructor() ERC721("KonduxERC721kNFT", "KonduxERC721kNFT") Ownable(msg.sender) {
        faucet();
    }

    function faucet() public {
        counter++;
        _mint(msg.sender, counter);
    }

    function safeMint(address to, uint256 dna) public {
        counter++;
        _mint(to, counter);
    }

    function getCounter() public view returns (uint256) {
        return counter;
    }

     /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding Solidity interface to learn more
     * about how these IDs are created.
     * @param interfaceId The interface identifier.
     * @return Whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal
        override(ERC721, ERC721Enumerable) 
        returns (address prevOwner) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal
        override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
}