// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @notice Lightweight Kondux NFT mock tailored for staking tests.
///         It mimics the subset of behaviour relied on by the Forge suite
///         without pulling the real implementation that requires Solidity 0.8.30.
contract MockKondux {
    string public name;
    string public symbol;
    uint256 public maxSupply;

    uint256 private _nextId;

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(address => uint256[]) private _ownedTokens;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensIndex;

    mapping(uint256 => uint256) private _dna;
    mapping(uint256 => mapping(uint8 => mapping(uint8 => uint256))) private _genes;
    mapping(uint256 => uint256) private _transferDate;
    uint96 private _denominator;

    constructor(
        string memory _name,
        string memory _symbol,
        address,
        address,
        address,
        address,
        address,
        uint256 _maxSupply
    ) {
        name = _name;
        symbol = _symbol;
        maxSupply = _maxSupply;
    }

    // ---------------- ERC721-lite view functions ----------------

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "Zero address");
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _ownerOf[tokenId];
        require(owner != address(0), "Nonexistent token");
        return owner;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        require(index < _ownedTokens[owner].length, "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    function totalSupply() external view returns (uint256) {
        return _nextId;
    }

    // ---------------- Minting helpers ----------------

    function safeMint(address to, uint256 dnaValue) external returns (uint256) {
        require(to != address(0), "Invalid recipient");
        uint256 tokenId = _nextId++;

        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;
        _ownedTokensIndex[to][tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);

        _dna[tokenId] = dnaValue;
        _transferDate[tokenId] = block.timestamp;

        return tokenId;
    }

    function burn(uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        require(owner != address(0), "Nonexistent token");

        // Clear ownership data
        _ownerOf[tokenId] = address(0);
        _balanceOf[owner] -= 1;

        uint256 lastIndex = _ownedTokens[owner].length - 1;
        uint256 tokenIndex = _ownedTokensIndex[owner][tokenId];

        if (tokenIndex != lastIndex) {
            uint256 lastTokenId = _ownedTokens[owner][lastIndex];
            _ownedTokens[owner][tokenIndex] = lastTokenId;
            _ownedTokensIndex[owner][lastTokenId] = tokenIndex;
        }

        _ownedTokens[owner].pop();
        delete _ownedTokensIndex[owner][tokenId];
        delete _dna[tokenId];
        delete _transferDate[tokenId];
    }

    // ---------------- DNA helpers ----------------

    function setDna(uint256 tokenId, uint256 dnaValue) external {
        require(_ownerOf[tokenId] != address(0), "Nonexistent token");
        _dna[tokenId] = dnaValue;
    }

    function getDna(uint256 tokenId) external view returns (uint256) {
        return _dna[tokenId];
    }

    function writeGen(uint256 tokenId, uint256 value, uint8 startIndex, uint8 endIndex) external {
        require(startIndex < endIndex, "Invalid range");
        require(_ownerOf[tokenId] != address(0), "Nonexistent token");
        _genes[tokenId][startIndex][endIndex] = value;
    }

    function readGen(uint256 tokenId, uint8 startIndex, uint8 endIndex) external view returns (int256) {
        return int256(_genes[tokenId][startIndex][endIndex]);
    }

    function getTransferDate(uint256 tokenId) external view returns (uint256) {
        return _transferDate[tokenId];
    }

    // ---------------- Royalty/admin stubs ----------------

    function changeDenominator(uint96 newDenominator) external returns (uint96) {
        _denominator = newDenominator;
        return newDenominator;
    }

    function setDefaultRoyalty(address, uint96) external {}

    function setTokenRoyalty(uint256, address, uint96) external {}

    function setBaseURI(string memory uri) external pure returns (string memory) {
        return uri;
    }

    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function faucet() external {}
}
