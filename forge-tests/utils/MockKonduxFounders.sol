// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title MockKonduxFounders
 * @notice Minimal KonduxFounders mock for MinterFounders tests
 * @dev Implements the IKonduxFounders interface subset needed for testing
 */
contract MockKonduxFounders {
    string public name;
    string public symbol;
    
    uint256 private _nextId;
    uint256 private _totalSupply;
    
    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    
    // Role management (simplified)
    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping(address => bytes32) public roles;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "Zero address");
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _ownerOf[tokenId];
        require(owner != address(0), "Nonexistent token");
        return owner;
    }

    /**
     * @notice Mints a new founders NFT
     * @dev Anyone can call this in the mock (no role check) for testing simplicity
     * @param to The recipient address
     * @return tokenId The minted token ID
     */
    function safeMint(address to) external returns (uint256) {
        require(to != address(0), "Invalid recipient");
        
        uint256 tokenId = _nextId++;
        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;
        _totalSupply += 1;
        
        return tokenId;
    }

    // Admin stubs (not really needed for tests but included for interface completeness)
    function changeDenominator(uint96) external pure returns (uint96) {
        return 0;
    }

    function setDefaultRoyalty(address, uint96) external {}

    function setTokenRoyalty(uint256, address, uint96) external {}

    function setBaseURI(string memory uri) external pure returns (string memory) {
        return uri;
    }

    function pause() external {}

    function unpause() external {}

    function setMinter(address minter) external {
        roles[minter] = MINTER_ROLE;
    }
}
