// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract Kondux1155 is ERC1155, AccessControl, ERC1155Pausable, ERC1155Burnable, ERC1155Supply {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");

     // Events emitted by the contract
    event BaseURIChanged(string baseURI);
    event DnaChanged(uint256 indexed tokenID, uint256 dna);
    event DnaModified(uint256 indexed tokenID, uint256 dna, uint256 inputValue, uint8 startIndex, uint8 endIndex);
    event RoleChanged(address indexed addr, bytes32 role, bool enabled);

    // The base URI for all token URIs
    string public baseURI;

    uint256 private _tokenIdCounter;

    mapping (uint256 => uint256) public indexDna; // Maps token IDs to DNA values

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(DNA_MODIFIER_ROLE, msg.sender);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Sets the base URI for token metadata.
     * Emits a BaseURIChanged event with the new base URI.
     *
     * @param _baseURI The new base URI.
     */
    function setBaseURI(string memory _baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(_baseURI);                    
    }

    function _setBaseURI(string memory _baseURI) internal returns (string memory){
        _setURI(_baseURI);
        emit BaseURIChanged(_baseURI);
        
        return _baseURI;
    }

    /**
     * @dev Returns the token URI for a given token ID.
     * Reverts if the token ID does not exist.
     *
     * @param tokenId The ID of the token.
     * @return The token URI.
     */
    function uri(uint256 tokenId) public view override(ERC1155) returns (string memory) {
        require(exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    function mint(address account, uint256 amount, uint256 dna)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        return _mintSequential(account, amount, dna);
    }

    function mintBatchSequential(address to, uint256[] memory amounts, uint256[] memory dnas)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256[] memory)
    {
        return _mintBatchSequential(to, amounts, dnas);
    }

    function mintWithData(address account, uint256 amount, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        return _mintSequentialWithData(account, amount, data);        
    }

    function mintBatchWithData(address to, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256[] memory)
    {
        return _mintBatchSequentialWithData(to, amounts, data);
    }

    function _setDna(uint256 tokenId, uint256 dna) internal {
        indexDna[tokenId] = dna;
        emit DnaChanged(tokenId, dna);
    }

    function _mintSequential(address account, uint256 amount, uint256 dna)
        internal
        returns (uint256)
    {
        uint256 id = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(account, id, amount, "");
        _setDna(id, dna);

        return id;
    }

    function _mintSequentialWithData(address account, uint256 amount, bytes memory data)
        internal
        returns (uint256)
    {
        uint256 id = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(account, id, amount, data);
        _setDna(id, 0);

        return id;
    }

    function _mintBatchSequentialWithData(address to, uint256[] memory amounts, bytes memory data)
        internal 
        returns (uint256[] memory)
    {
        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            ids[i] = _tokenIdCounter;
            _tokenIdCounter++;
        }
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            _setDna(ids[i], 0);
        }

        return ids;
    }

    function _mintBatchSequential(address to, uint256[] memory amounts, uint256[] memory dnas)
        internal
        returns (uint256[] memory)
    {
        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            ids[i] = _tokenIdCounter;
            _tokenIdCounter++;
        }
        _mintBatch(to, ids, amounts, "");
        for (uint256 i = 0; i < ids.length; i++) {
            _setDna(ids[i], dnas[i]);
        }

        return ids;
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}