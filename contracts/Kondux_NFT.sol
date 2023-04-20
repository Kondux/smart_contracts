// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./types/AccessControlled.sol";


contract Kondux is ERC721, ERC721Enumerable,Pausable, ERC721Burnable, ERC721Royalty, AccessControlled {
    event BaseURIChanged(string baseURI);
    event Received(address sender, uint value);
    event DnaChanged(uint256 tokenID, uint256 dna);
    event DenominatorChanged(uint96 denominator);
    event DnaModified(uint256 indexed tokenID, uint256 dna, uint256 inputValue, uint8 startIndex, uint8 endIndex);


    using Counters for Counters.Counter;

    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");

    string public baseURI;
    uint96 public denominator;
    
    mapping (uint256 => uint256) public indexDna;

    Counters.Counter private _tokenIdCounter;

    constructor(string memory _name, string memory _symbol, address _authority) 
        ERC721(_name, _symbol) 
        AccessControlled(IAuthority(_authority)) {
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
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    function pause() public onlyGovernor {
        _pause();
    }

    function unpause() public onlyGovernor {
        _unpause();
    }

    function safeMint(address to, uint256 dna) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _setDna(tokenId, dna);
        _safeMint(to, tokenId);
        return tokenId;
    }

    function setDna(uint256 _tokenID, uint256 _dna) public onlyGovernor {
        _setDna(_tokenID, _dna);
    }

    function getDna (uint256 _tokenID) public view returns (uint256) {
        require(_exists(_tokenID), "ERC721Metadata: URI query for nonexistent token");
        return indexDna[_tokenID];
    }

    function readDNA(uint256 _tokenID, uint8 startIndex, uint8 endIndex) public view returns (int256) {
        require(startIndex < endIndex && endIndex <= 32, "Invalid range");

        uint256 originalValue = indexDna[_tokenID];
        uint256 extractedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            assembly {
                let bytePos := sub(31, i) // Reverse the index since bytes are stored in big-endian
                let shiftAmount := mul(8, bytePos)

                // Extract the byte from the original value at the current position
                let extractedByte := and(shr(shiftAmount, originalValue), 0xff)

                // Shift the extracted byte to the left by the number of positions
                // from the start of the requested range
                let adjustedShiftAmount := mul(8, sub(i, startIndex))

                // Combine the shifted byte with the previously extracted bytes
                extractedValue := or(extractedValue, shl(adjustedShiftAmount, extractedByte))
            }
        }

        return int256(extractedValue);
    }

    function writeDNA(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex) public {
        require(startIndex < endIndex && endIndex <= 32, "Invalid range");
        require(inputValue >= 0, "Only positive values are supported");

        uint256 originalValue = indexDna[_tokenID];
        uint256 mask;
        uint256 updatedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            assembly {
                let bytePos := sub(31, i) // Reverse the index since bytes are stored in big-endian
                let shiftAmount := mul(8, bytePos)

                // Prepare the mask for the current byte
                mask := or(mask, shl(shiftAmount, 0xff))

                // Prepare the updated value
                updatedValue := or(updatedValue, shl(shiftAmount, and(shr(mul(8, sub(i, startIndex)), inputValue), 0xff)))
            }
        }

        // Clear the bytes in the specified range of the original value, then store the updated value
        indexDna[_tokenID] = (originalValue & ~mask) | (updatedValue & mask);


        // Emit the BytesRangeModified event
        emit DnaModified(_tokenID, indexDna[_tokenID], inputValue, startIndex, endIndex); 
    }

    function faucet() public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function faucetBonus(uint256 _bonus) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        writeDNA(tokenId, _bonus, 1, 2); 
    }  
  
    // Internal functions //

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _setDna(uint256 _tokenID, uint256 _dna) internal {
        indexDna[_tokenID] = _dna;
        emit DnaChanged(_tokenID, _dna);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override (ERC721Royalty, ERC721) {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
