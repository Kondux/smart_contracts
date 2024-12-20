// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../types/AccessControlled.sol";


contract KBox is ERC721, ERC721Enumerable, Pausable, ERC721Burnable, ERC721Royalty, AccessControlled {
    event BaseURIChanged(string baseURI);
    event Received(address sender, uint value);
    event DnaChanged(uint256 tokenID, uint256 dna);
    event DenominatorChanged(uint96 denominator);

    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");

    string public baseURI;
    uint96 public denominator;
    
    mapping (uint256 => uint256) public indexDna;

    uint256 private _tokenIdCounter;

    constructor(string memory _name, string memory _symbol, address _authority) 
        ERC721(_name, _symbol) 
        AccessControlled(IAuthority(_authority)) {
    }

    function faucet() public {
        _tokenIdCounter++;
        _safeMint(msg.sender, _tokenIdCounter);
    }

    function changeDenominator(uint96 _denominator) public onlyGovernor returns (uint96) {
        denominator = _denominator;
        emit DenominatorChanged(denominator);
        return denominator;
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyGovernor {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function setTokenRoyalty(uint256 tokenId,address receiver,uint96 feeNumerator) public onlyGovernor {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function setBaseURI(string memory _newURI) external onlyGovernor returns (string memory) {
        baseURI = _newURI;
        emit BaseURIChanged(baseURI);
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    function pause() public onlyGovernor {
        _pause();
    }

    function unpause() public onlyGovernor {
        _unpause();
    }

    function safeMint(address to, uint256 dna) public onlyGlobalRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _setDna(tokenId, dna);
        _safeMint(to, tokenId);
        return tokenId;
    }

    function setDna(uint256 _tokenID, uint256 _dna) public onlyGovernor {
        _setDna(_tokenID, _dna);
    }

    function getDna (uint256 _tokenID) public view returns (uint256) {
        return indexDna[_tokenID];
    }  

    // Internal functions //

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _setDna(uint256 _tokenID, uint256 _dna) internal {
        indexDna[_tokenID] = _dna;
        emit DnaChanged(_tokenID, _dna);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal
        whenNotPaused
        override(ERC721, ERC721Enumerable) 
        returns (address prevOwner) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal
        whenNotPaused
        override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
}