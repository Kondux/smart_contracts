// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Kondux
 * @notice Inherits multiple OpenZeppelin contracts (ERC721, ERC721Enumerable, Burnable, Royalty, AccessControl)
 *         and includes EIP-4906 for metadata update notifications, as well as emergency withdrawal functions.
 * @dev This contract is a base contract for creating NFTs with DNA and royalty support.
 *     It includes functions for minting, DNA reading/writing, and role management.
 *    It also includes functions for setting base URI, changing denominator, and updating metadata.
 *    The contract also includes functions for emergency withdrawal of ETH, ERC20, and ERC721 tokens.
 */
contract Kondux is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Royalty,
    AccessControl,
    IERC4906
{
    uint256 private _tokenIdCounter;

    // Events from the original contract
    event BaseURIChanged(string baseURI);
    event DnaChanged(uint256 indexed tokenID, uint256 dna);
    event DenominatorChanged(uint96 denominator);
    event DnaModified(uint256 indexed tokenID, uint256 dna, uint256 inputValue, uint8 startIndex, uint8 endIndex);
    event RoleChanged(address indexed addr, bytes32 role, bool enabled);
    event FreeMintingChanged(bool freeMinting);

    // Role definitions
    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");

    // Contract state variables
    string public baseURI;
    uint96 public denominator;
    bool public freeMinting;

    // Mapping from token ID to DNA value
    mapping(uint256 => uint256) public indexDna;

    // Mapping from token ID to last transfer timestamp
    mapping(uint256 => uint256) public transferDates;

    /**
     * @dev Initializes the Kondux contract with a name and symbol.
     *      Grants DEFAULT_ADMIN_ROLE, MINTER_ROLE, and DNA_MODIFIER_ROLE to the deployer.
     * @param _name   The name of the token (e.g., "Kondux").
     * @param _symbol The symbol of the token (e.g., "KDX").
     * @dev This function is only called once during deployment.
     * It is used to set the name and symbol of the token, as well as grant roles to the deployer.
     * The deployer is automatically granted DEFAULT_ADMIN_ROLE, MINTER_ROLE, and DNA_MODIFIER_ROLE.
     * The deployer can then grant these roles to other addresses as needed.
     * The denominator is set to 10,000 by default.
     * The base URI is set to an empty string by default.
     * The contract is initialized with an empty token ID counter.
     * The contract is initialized with an empty mapping for DNA values.
     * The contract is initialized with an empty mapping for transfer dates.
     */
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {
        freeMinting = false;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(DNA_MODIFIER_ROLE, msg.sender);
    }

    // -------------------- Modifiers -------------------- //

    /**
     * @dev Throws if called by any account other than the admin.
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "kNFT: only admin");
        _;
    }

    /**
     * @dev Throws if called by any account other than the minter. If freeMinting is enabled, anyone can mint.
     */
    modifier onlyMinter() {
        if (!freeMinting) {
            require(hasRole(MINTER_ROLE, msg.sender), "kNFT: only minter");
        }
        _;
    }

    /**
     * @dev Throws if called by any account other than the DNA modifier.
     */
    modifier onlyDnaModifier() {
        require(hasRole(DNA_MODIFIER_ROLE, msg.sender), "kNFT: only dna modifier");
        _;
    }

    // -------------------- Royalty Functions -------------------- //

    /**
     * @dev Changes the numerator used for calculating royalty fees if needed.
     *      Also emits DenominatorChanged event.
     * @param _denominator New denominator to set (commonly 10,000 if you do fees in basis points).
     * @return The new denominator.
     * @dev This function is only callable by the admin.
     *  It is used to set the denominator for royalty calculations.
     */
    function changeDenominator(uint96 _denominator) public onlyAdmin returns (uint96) {
        denominator = _denominator;
        emit DenominatorChanged(denominator);
        return denominator;
    }

    /**
     * @dev Sets the default royalty for all tokens in this collection.
     * @param receiver The address that will receive royalty payments.
     * @param feeNumerator The fee numerator (e.g., 100 = 1% if denominator is 10,000).
     * @dev This function is only callable by the admin.
     * It is used to set a default royalty for all tokens in the collection.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyAdmin {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Sets a custom royalty for a specific token ID.
     * @param tokenId The token to apply the custom royalty.
     * @param receiver The address that will receive the royalty.
     * @param feeNumerator The fee numerator (e.g., 100 = 1% if denominator is 10,000).
     * @dev This function is only callable by the admin.
     * It is used to set a custom royalty for a specific token ID.
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator)
        public
        onlyAdmin
    {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    // -------------------- Base URI and Metadata -------------------- //

    /**
     * @dev Sets the base URI used to construct {tokenURI} for all tokens.
     *      Emits BaseURIChanged event.
     * @param _newURI New base URI for metadata.
     * @return The new base URI.
     * @dev This function is only callable by the admin.
     *  It is used to set the base URI for all tokens in the collection.
     */
    function setBaseURI(string memory _newURI) external onlyAdmin returns (string memory) {
        baseURI = _newURI;
        emit BaseURIChanged(baseURI);
        return baseURI;
    }

    /**
     * @dev Returns the URI for a given token ID, constructed by concatenating baseURI and the token ID.
     * @param tokenId The token ID to retrieve metadata for.
     * @return The URI for the given token ID.
     * @dev This function is view-only and does not modify the base URI.
     *  It is used to read the URI for a specific token ID.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "kNFT: query for nonexistent token");
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, Strings.toString(tokenId)))
            : "";
    }

    /**
     * @dev Returns the base URI set in the contract.
     * @return The base URI for all tokens.
     * @dev This function is view-only and does not modify the base URI.
     *   It is used to read the base URI for all tokens.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // -------------------- Minting and DNA -------------------- //

    /**
     * @dev Safely mints a new token to address `to` with the given `dna` value.
     * @param to Address that will receive the newly minted token.
     * @param dna The DNA value to associate with the new token.
     * @return tokenId The new token ID.
     * @dev This function is only callable by the minter.
     *   It is used to mint a new token with a specified DNA value.
     */
    function safeMint(address to, uint256 dna) public onlyMinter returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _setDna(tokenId, dna);
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev Sets the freeMinting flag to enable/disable free minting.
     * @param _freeMinting True to enable free minting, false to disable.
     */
    function setFreeMinting(bool _freeMinting) public onlyAdmin {
        freeMinting = _freeMinting;
        emit FreeMintingChanged(freeMinting);
    }

    /**
     * @dev Sets a token's DNA value. Requires DNA_MODIFIER_ROLE.
     * @param _tokenID ID of the token to modify.
     * @param _dna New DNA value.
     * @dev This function is only callable by the DNA modifier.
     *   It is used to set the DNA value of a token after minting.
     */
    function setDna(uint256 _tokenID, uint256 _dna) public onlyDnaModifier {
        _setDna(_tokenID, _dna);
    }

    /**
     * @dev Internal function to set DNA for a token and emit DnaChanged.
     * @param _tokenID ID of the token to modify.
     * @param _dna New DNA value.
     * @dev This function is only callable by the DNA modifier.
     *    It is used by both setDna and safeMint functions.
     */
    function _setDna(uint256 _tokenID, uint256 _dna) internal {
        indexDna[_tokenID] = _dna;
        emit DnaChanged(_tokenID, _dna);
    }

    /**
     * @dev Returns the DNA value of a given token.
     * @param _tokenID The token ID to query.
     * @return The DNA value of the token.
     * @dev This function is view-only and does not modify the DNA.
     *    It is used to read the DNA value of a token.
     */
    function getDna(uint256 _tokenID) public view returns (uint256) {
        require(_ownerOf(_tokenID) != address(0), "kNFT: nonexistent token");
        return indexDna[_tokenID];
    }

    // -------------------- DNA Gene Reading/Writing -------------------- //

    /**
     * @dev Reads a specified byte range from the DNA. Returns the extracted value as int256.
     * @param _tokenID   ID of the token to read from.
     * @param startIndex The start index of the range to read.
     * @param endIndex  The end index of the range to read.
     * @return extractedValue The extracted value as int256.
     * @dev This function is view-only and does not modify the DNA.
     *     It is used to read a specific range of bytes from the DNA.
     */
    function readGen(uint256 _tokenID, uint8 startIndex, uint8 endIndex)
        public
        view
        returns (int256)
    {
        require(startIndex < endIndex && endIndex <= 32, "kNFT: Invalid range");
        require(_ownerOf(_tokenID) != address(0), "kNFT: nonexistent token");

        uint256 originalValue = indexDna[_tokenID];
        uint256 extractedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            /* solhint-disable no-inline-assembly */
            assembly {
                let bytePos := sub(31, i) // Reverse index for big-endian
                let shiftAmount := mul(8, bytePos)
                let extractedByte := and(shr(shiftAmount, originalValue), 0xff)
                let adjustedShiftAmount := mul(8, sub(i, startIndex))
                extractedValue := or(extractedValue, shl(adjustedShiftAmount, extractedByte))
            }
            /* solhint-enable no-inline-assembly */
        }

        return int256(extractedValue);
    }

    /**
     * @dev Writes a specified byte range to the DNA, injecting inputValue into [startIndex..endIndex).
     * @param _tokenID   ID of the token to modify.
     * @param inputValue The value to write.
     * @param startIndex The start index of the range to write.
     * @param endIndex   The end index of the range to write.
     * @dev This function is only callable by the DNA modifier.
     *    It emits DnaModified on completion.
     */
    function writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex)
        public
        onlyDnaModifier
    {
        _writeGen(_tokenID, inputValue, startIndex, endIndex);
    }

    /**
     * @dev Internal function to perform the DNA writing. Emits DnaModified on completion.
     * @param _tokenID   ID of the token to modify.
     * @param inputValue The value to write.
     * @param startIndex The start index of the range to write.
     * @param endIndex   The end index of the range to write.
     * @dev This function is only callable by the DNA modifier.
     *     It is used by both writeGen and setDna functions.
     */
    function _writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex)
        internal
    {
        require(startIndex < endIndex && endIndex <= 32, "kNFT: Invalid range");
        require(_ownerOf(_tokenID) != address(0), "kNFT: nonexistent token");
        require(inputValue >= 0, "kNFT: Only positive values");

        uint256 maxInputValue = (1 << ((endIndex - startIndex) * 8)) - 1;
        require(inputValue <= maxInputValue, "kNFT: Input too large");

        uint256 originalValue = indexDna[_tokenID];
        uint256 mask;
        uint256 updatedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            /* solhint-disable no-inline-assembly */
            assembly {
                let bytePos := sub(31, i)
                let shiftAmount := mul(8, bytePos)
                mask := or(mask, shl(shiftAmount, 0xff))
                updatedValue := or(
                    updatedValue,
                    shl(
                        shiftAmount,
                        and(shr(mul(8, sub(i, startIndex)), inputValue), 0xff)
                    )
                )
            }
            /* solhint-enable no-inline-assembly */
        }

        // Clear bytes in specified range, then store new bits
        indexDna[_tokenID] = (originalValue & ~mask) | (updatedValue & mask);
        emit DnaModified(_tokenID, indexDna[_tokenID], inputValue, startIndex, endIndex);
    }

    // -------------------- Access Control Adjustments -------------------- //

    /**
     * @dev Grants or revokes a role on a specific address.
     * @param role    The role to modify.
     * @param addr    The address to grant/revoke the role.
     * @param enabled True to grant, false to revoke.
     * @dev This function is only callable by the admin.
     */
    function setRole(bytes32 role, address addr, bool enabled) public onlyAdmin {
        if (enabled) {
            _grantRole(role, addr);
        } else {
            _revokeRole(role, addr);
        }
        emit RoleChanged(addr, role, enabled);
    }

    // -------------------- Transfer Timestamp -------------------- //

    /**
     * @dev Returns the timestamp of the last transfer for a given token ID.
     * @param tokenId The token ID to query.
     * @return The timestamp of the last transfer.
     */
    function getTransferDate(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "kNFT: nonexistent token");
        return transferDates[tokenId];
    }

    // -------------------- EIP-4906: Metadata Update Support -------------------- //

    /**
     * @dev For EIP-4906, we declare that we support the 0x49064906 interface,
     *      and add functions to emit MetadataUpdate or BatchMetadataUpdate events.
     * @param interfaceId The interface ID to check for support.
     * @return True if the contract supports the interface, false otherwise.
     * @dev This function overrides the supportsInterface function in IERC165.
     *     It checks for the EIP-4906 interface ID (0x49064906) in addition to the other interfaces.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, ERC721Royalty, AccessControl, IERC165)
        returns (bool)
    {
        // EIP-4906 interface ID is 0x49064906
        return (interfaceId == 0x49064906) || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Manually emit a MetadataUpdate event to indicate that metadata for a specific token changed.
     *      (Call this whenever you change metadata or want to notify off-chain apps.)
     * @param tokenId The token whose metadata changed.
     */
    function emitMetadataUpdate(uint256 tokenId) external onlyAdmin {
        require(_ownerOf(tokenId) != address(0), "kNFT: nonexistent token");
        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev Manually emit a BatchMetadataUpdate event to indicate that metadata for a range of tokens changed.
     * @param fromTokenId The start of the range.
     * @param toTokenId   The end of the range.
     * @dev This function is only callable by the admin.
     */
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) external onlyAdmin {
        require(fromTokenId <= toTokenId, "kNFT: invalid range");
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    // -------------------- Emergency Withdrawal -------------------- //

    /**
     * @dev Withdraws ETH stuck in this contract to a specified address.
     * @param to Recipient address to receive the withdrawn Ether.
     * @dev This function is only callable by the admin.
     *    It is intended for emergency use only, and should be used with caution.
     */
    function emergencyWithdrawETH(address to) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        uint256 amount = address(this).balance;
        (bool success, ) = to.call{value: amount}("");
        require(success, "kNFT: ETH transfer failed");
    }

    /**
     * @dev Withdraws ERC20 tokens stuck in this contract.
     * @param token  The ERC20 token contract address.
     * @param to     Recipient address to receive the tokens.
     * @param amount Amount of tokens to withdraw.
     * @dev This function is only callable by the admin.
     *    It is intended for emergency use only, and should be used with caution.
     */
    function emergencyWithdrawToken(IERC20 token, address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        require(token.transfer(to, amount), "kNFT: transfer failed");
    }

    /**
     * @dev Withdraws an ERC721 NFT stuck in this contract.
     * @param nft     The ERC721 contract address.
     * @param to      Recipient address to receive the NFT.
     * @param tokenId The NFT token ID to withdraw.
     * @dev This function is only callable by the admin.
     *     It is intended for emergency use only, and should be used with caution.
     */
    function emergencyWithdrawNFT(IERC721 nft, address to, uint256 tokenId) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        nft.transferFrom(address(this), to, tokenId);
    }

    // -------------------- Internal Overrides -------------------- //

    /**
     * @dev Hook to handle enumerability and transfer date updates.
     * @param to      Address to transfer to.
     * @param tokenId Token ID to transfer.
     * @param auth    Address authorizing the transfer.
     * @return prevOwner Address of the previous owner.
     * @dev Overrides both ERC721 and ERC721Enumerable functions.     
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address prevOwner)
    {
        prevOwner = super._update(to, tokenId, auth);
        if (to != address(0)) {
            // track the transfer date
            transferDates[tokenId] = block.timestamp;
        }
    }

    /**
     * @dev For enumerability as required by ERC721Enumerable.
     * @param account Address to query.
     * @param value  Value to increase by.
     * @dev Overrides both ERC721 and ERC721Enumerable functions.
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }
}
