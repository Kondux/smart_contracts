// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ---------------------------------------
// OpenZeppelin imports
// ---------------------------------------
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC4907.sol";

/**
 * @title Kondux
 * @notice NFT contract that enforces royalties in KNDX, pegged to 0.001 ETH
 *         (exemptions for founder pass holders and original minter, optional 1% treasury fee).
 */
contract Kondux is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Royalty,
    AccessControl,
    IERC4906,
    IERC4907
{
    // -------------------- Roles & Events -------------------- //

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");

    event BaseURIChanged(string baseURI);
    event DnaChanged(uint256 indexed tokenID, uint256 dna);
    event DenominatorChanged(uint96 denominator);
    event DnaModified(uint256 indexed tokenID, uint256 dna, uint256 inputValue, uint8 startIndex, uint8 endIndex);
    event RoleChanged(address indexed addr, bytes32 role, bool enabled);
    event FreeMintingChanged(bool freeMinting);
    
    event RoyaltySplitsChanged(uint96 manufacturerBP, uint96 partnerBP, uint96 creatorBP);
    event PartnerWalletChanged(address partner);

    // -------------------- Config Addresses (Set in Constructor) -------------------- //

    /// @dev WETH address (wrapped ETH)
    address public WETH;
    /// @dev KNDX token address
    address public KNDX;
    /// @dev Founder’s pass contract
    IERC721 public foundersPass;
    /// @dev Kondux treasury address (receives 1% of each royalty)
    address public konduxTreasury;

    /// @notice The Uniswap V2 Pair interface used to determine token/ETH price ratios.
    IUniswapV2Pair public uniswapV2Pair;

    // -------------------- Royalty Settings / Toggles -------------------- //

    /// @dev If `true`, we enforce the on-chain royalty logic in _update()
    bool public royaltyEnforcementEnabled = true;

    /// @dev If `true`, holders of the founder pass are exempt from paying royalties
    bool public founderPassExemptEnabled = true;

    /// @dev If `true`, the original minter (royalty owner) is exempt when sending
    bool public mintedOwnerExemptEnabled = true;

    /// @dev If `true`, we take 1% of the royalty for the treasury, 99% goes to the NFT’s royalty owner
    bool public treasuryFeeEnabled = true;

    // -------------------- EIP-4907 Toggle -------------------- //

    /**
     * @notice If this is `false`, EIP-4907 functionality is disabled.
     *         - `setUser` will revert
     *         - `userOf` and `userExpires` will return default values
     *         - We do not declare support for 0xad092b5c in `supportsInterface`.
     */
    bool public eip4907Enabled = true;

    // -------------------- Core NFT State -------------------- //

    /// @dev Maximum mintable supply. If `maxSupply` is 0, supply is infinite.
    uint256 public maxSupply;
    string public baseURI;
    uint96 public denominator;       // for ERC721Royalty usage (optional)
    bool public freeMinting;        // if true, anyone can mint (else only MINTER_ROLE)
    uint256 private _tokenIdCounter;

    // DNA mapping
    mapping(uint256 => uint256) public indexDna;

    // -------------------- Per-Token Royalty in ETH (wei) -------------------- //

    /**
     * @dev The address that receives the royalty portion for each token.
     *      This is set to the `to` address at mint time.
     */
    mapping(uint256 => address) public royaltyOwnerOf;

    /**
     * @dev The royalty amount in **wei** for each token. 
     *      e.g. if `royaltyETHWei[tokenId] = 1e15`, that's 0.001 ETH pegged. 
     *      If it's 0, that token charges no royalty on transfer.
     */
    mapping(uint256 => uint256) public royaltyETHWei;

    /**
     * @dev User information for the ERC4907 interface.
     *     This struct contains the user address and the expiration time of the user role.
     *     The user role allows a specific address to use the NFT for a limited time.
     */
    struct UserInfo {
        address user;   // address of the user role
        uint64 expires; // UNIX timestamp when the user role expires
    }

    /// @dev Mapping from token ID to user information for the ERC4907 interface.
    mapping(uint256 => UserInfo) private _users;

    /// @dev Royalty split percentages (in basis points)
    uint96 public manufacturerCutBP = 4000; // 40 % (manufacturer / treasury)
    uint96 public partnerCutBP      = 3000; // 30 % (partner)
    uint96 public creatorCutBP      = 3000; // 30 % (creator)

    address public partnerWallet;     // if 0x0 ⇒ use creator


    // -------------------- Constructor -------------------- //

    /**
     * @dev Initializes the Kondux contract.
     * @param _name         ERC721 name
     * @param _symbol       ERC721 symbol
     * @param _uniswapPair  Uniswap V2 pair address
     * @param _weth          WETH address
     * @param _kndx          KNDX token address
     * @param _foundersPass  Founder pass NFT
     * @param _treasury      Kondux treasury address
     * @param _maxSupply    Set a maximum supply limit. 0 => infinite supply
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _uniswapPair, 
        address _weth,
        address _kndx,
        address _foundersPass,
        address _treasury,
        uint256 _maxSupply
    )
        ERC721(_name, _symbol)
    {
        // grant admin + roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(DNA_MODIFIER_ROLE, msg.sender);

        // init config
        uniswapV2Pair = IUniswapV2Pair(_uniswapPair); 
        WETH = _weth;
        KNDX = _kndx;
        foundersPass = IERC721(_foundersPass);
        konduxTreasury = _treasury;
        maxSupply = _maxSupply;

        // optional defaults
        denominator = 10000;
        freeMinting = false;
    }

    // -------------------- Admin: Toggle/Set Functions -------------------- //

    /**
     * @dev Restricts access to functions using this modifier to accounts that have the admin role.
     * Reverts with "kNFT: only admin" if the caller is not an admin.
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "kNFT: only admin");
        _;
    }

    /**
     * @notice Sets the partner wallet address.
     * @dev This function can only be called by an admin. It updates the partner wallet address used for royalty splits.
     * @param _partner The new partner wallet address. If set to zero, the creator's address will be used instead.
     */
    function setPartnerWallet(address _partner) external onlyAdmin {
        partnerWallet = _partner;
    }
    /**
     * @notice Sets the royalty split percentages for manufacturer, partner, and creator.
     * @dev This function can only be called by an admin. It updates the basis points for each role.
     * @param _manufacturerCutBP The basis points for the manufacturer cut (e.g., 4000 = 40%).
     * @param _partnerCutBP The basis points for the partner cut (e.g., 3000 = 30%).
     * @param _creatorCutBP The basis points for the creator cut (e.g., 3000 = 30%).
     */
    function setRoyaltySplits(uint96 _manufacturerCutBP, uint96 _partnerCutBP, uint96 _creatorCutBP) external onlyAdmin {
        // Require that the total royalty cuts match 100% (denominator calculated in basis points)
        require(
            _manufacturerCutBP + _partnerCutBP + _creatorCutBP == denominator, 
            "kNFT: total royalty cuts must equal 100%"
        );

        // Update the royalty cuts
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP = _partnerCutBP;
        creatorCutBP = _creatorCutBP;
    }

    /**
     * @notice Sets the royalty recipient for a specific token.
     * @dev This function can only be called by an admin or the token owner. It updates the royalty owner for the specified token ID.
     * @param tokenId The identifier of the token whose royalty owner is being set.
     * @param royaltyOwner The address that will receive royalties for this token.
     */
    function setRoyaltyOwner(uint256 tokenId, address royaltyOwner) external {
        // Allow only the admin or the current royalty owner to set a new royalty owner
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || 
            royaltyOwnerOf[tokenId] == msg.sender, 
            "kNFT: only admin or royalty owner"
        );

        require(royaltyOwner != address(0), "kNFT: invalid royalty owner");

        // Set the new royalty owner
        royaltyOwnerOf[tokenId] = royaltyOwner;
    } 

    /**
     * @notice Enables or disables the enforcement of royalty settings.
     * @dev This function can only be called by an administrator. It updates the state variable that controls whether royalties are enforced.
     * @param _enabled A boolean flag indicating if royalty enforcement should be enabled (true) or disabled (false).
     */
    function setRoyaltyEnforcement(bool _enabled) external onlyAdmin {
        royaltyEnforcementEnabled = _enabled;
    }

    /**
     * @notice Enables or disables the founder pass exemption.
     * @dev Can only be called by an admin.
     * @param _enabled A boolean value indicating whether to enable (true) or disable (false) the exemption.
     */
    function setFounderPassExempt(bool _enabled) external onlyAdmin {
        founderPassExemptEnabled = _enabled;
    }

    /**
     * @notice Enable or disable the exemption for minted owners.
     * @dev This function allows an admin to change the state of the minted owner exemption feature.
     * @param _enabled A boolean flag indicating whether the minted owner exemption is enabled (true) or disabled (false).
     */
    function setMintedOwnerExempt(bool _enabled) external onlyAdmin {
        mintedOwnerExemptEnabled = _enabled;
    }

    /**
     * @notice Enables or disables the treasury fee.
     * @dev This function can only be called by an admin due to the onlyAdmin modifier.
     * @param _enabled A boolean value indicating whether the treasury fee should be enabled (true) or disabled (false).
     */
    function setTreasuryFeeEnabled(bool _enabled) external onlyAdmin {
        treasuryFeeEnabled = _enabled;
    }

    /**
     * @notice Enables or disables the EIP-4907 functionality.
     * @dev This function can only be called by an admin. If disabled, it will revert calls to setUser and return default values for userOf and userExpires.
     * @param enabled A boolean value indicating whether EIP-4907 functionality should be enabled (true) or disabled (false).
     */
    function setEip4907Enabled(bool enabled) external onlyAdmin {
        eip4907Enabled = enabled;
    }

    /**
     * @notice Sets the contract addresses for the Uniswap router, WETH, KNDX, founders pass NFT, and treasury.
     * @dev Can only be called by an address with admin privileges (onlyAdmin modifier).
     * @param _uniswapV2Pair The address of the Uniswap V2 pair contract.
     * @param _weth The address of the Wrapped Ether (WETH) contract.
     * @param _kndx The address of the KNDX token contract.
     * @param _foundersPass The address of the founders pass NFT contract.
     * @param _treasury The address of the treasury contract.
     */
    function setAddresses(
        address _uniswapV2Pair,
        address _weth,
        address _kndx,
        address _foundersPass,
        address _treasury
    ) external onlyAdmin {
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        WETH = _weth;
        KNDX = _kndx;
        foundersPass = IERC721(_foundersPass);
        konduxTreasury = _treasury;
    }

    /**
     * @notice Changes the denominator used in the contract.
     * @dev This function is restricted to admin users only.
     * @param _denominator The new denominator value that will replace the current one.
     * @return The updated denominator after the change.
     * 
     * Emits a {DenominatorChanged} event indicating the new denominator value.
     */
    function changeDenominator(uint96 _denominator) public onlyAdmin returns (uint96) {
        // Adjust the royalty cuts to match the new denominator value by recalculating their basis points with the old and new denominators.
        require(_denominator > 0, "kNFT: denominator must be > 0");

        // If the new denominator is the same as the current one, no need to change
        if (_denominator == denominator) {
            return denominator;
        }

        // Recalculate the royalty cuts based on the new denominator
        uint96 _manufacturerCutBP = (manufacturerCutBP * _denominator) / denominator;
        uint96 _partnerCutBP = (partnerCutBP * _denominator) / denominator;
        uint96 _creatorCutBP = (creatorCutBP * _denominator) / denominator;
        // Ensure the total royalty cuts match 100% with the provided denominator
        require(
            (_manufacturerCutBP + _partnerCutBP + _creatorCutBP) == _denominator,
            "kNFT: total royalty cuts must match denominator"
        );

        // Update the royalty cuts
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP = _partnerCutBP;
        creatorCutBP = _creatorCutBP;

        // Update the denominator
        denominator = _denominator;
        
        emit DenominatorChanged(denominator);
        return denominator;
    }

    /**
     * @notice Updates whether minting is free.
     * @dev This function can only be called by an admin, ensuring that only authorized users can change the minting state.
     *      It emits a FreeMintingChanged event upon updating the state.
     * @param _freeMinting The new state for free minting; true to enable, false to disable.
     */
    function setFreeMinting(bool _freeMinting) public onlyAdmin {
        freeMinting = _freeMinting;
        emit FreeMintingChanged(_freeMinting);
    }

    // -------------------- Per-Token Royalty (ETH) Management -------------------- //

    /**
     * @dev The royaltyOwnerOf[tokenId] can set or update the royalty in wei.
     *      e.g. 1e15 = 0.001 ETH. Setting it to 0 means no royalty for that token.
     */
    function setTokenRoyaltyEth(uint256 tokenId, uint256 ethAmountWei) external {
        require(royaltyOwnerOf[tokenId] == msg.sender, "Not the token's royalty owner");
        royaltyETHWei[tokenId] = ethAmountWei; // if set to 0 => no royalty
    }

    // -------------------- Minting & DNA -------------------- //

    /**
     * @dev Modifier to restrict function access to minter accounts when free minting is disabled.
     *
     * When the freeMinting flag is off (false), this modifier requires the caller to
     * possess the MINTER_ROLE. If the caller does not have the necessary role, the
     * transaction is reverted with an error message indicating that only minter
     * accounts can execute the function. If free minting is enabled, the role check
     * is bypassed.
     *
     * Usage Example:
     * function mintNFT(...) external onlyMinter {
     *     // minting logic
     * }
     */
    modifier onlyMinter() { 
        if (!freeMinting) {
            require(hasRole(MINTER_ROLE, msg.sender), "kNFT: only minter");
        }
        _;
    }

    /**
     * @dev Ensures that the function can only be called by an account with the DNA_MODIFIER_ROLE.
     * Reverts with "kNFT: only dna modifier" if the caller does not have the required role.
     */
    modifier onlyDnaModifier() {
        require(hasRole(DNA_MODIFIER_ROLE, msg.sender), "kNFT: only dna modifier");
        _;
    }

    /**
     * @notice Mints a new NFT token with a default royalty.
     * @dev Only accounts with the 'minter' role can call this function. The function increments the internal token ID counter,
     * sets the token's DNA, assigns the recipient address as the royalty owner, and sets the default royalty to 0.001 ETH (1e15 wei).
     * @param to The address that will receive the newly minted token.
     * @param dna The unique DNA value associated with the token.
     * @return tokenId The identifier of the minted token.
     */
    function safeMint(address to, uint256 dna) public onlyMinter returns (uint256) {
        // If maxSupply is set (non-zero), enforce it
        require(maxSupply == 0 || _tokenIdCounter < maxSupply, "Max supply reached");

        uint256 tokenId = _tokenIdCounter++;
        _setDna(tokenId, dna);

        // The newly minted NFT's "royalty owner" is the minter (the `to` address).
        // Default is 0.001 ETH => 1e15 wei
        royaltyOwnerOf[tokenId] = to;
        royaltyETHWei[tokenId] = 1e15; // 0.001 ETH

        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice Sets the DNA for a specific token.
     * @dev Only accounts with the designated DNA modifier role can call this function.
     * @param _tokenID The unique identifier of the token to update.
     * @param _dna The new DNA value to assign to the token.
     */
    function setDna(uint256 _tokenID, uint256 _dna) public onlyDnaModifier {
        _setDna(_tokenID, _dna);
    }

    /**
     * @notice Batch update DNA for multiple tokens in a gas-optimized manner.
     * @param tokenIDs The array of token IDs to update.
     * @param dnas The corresponding array of DNA values to set.
     */
    function batchSetDna(uint256[] calldata tokenIDs, uint256[] calldata dnas) external onlyDnaModifier {
        uint256 len = tokenIDs.length;
        require(len == dnas.length, "kNFT: array length mismatch");
        for (uint256 i = 0; i < len; ) {
            uint256 tokenId = tokenIDs[i];
            uint256 dna = dnas[i];
            indexDna[tokenId] = dna;
            emit DnaChanged(tokenId, dna);
            emit MetadataUpdate(tokenId);
            unchecked { ++i; }
        }
    }

    /**
     * @notice Updates the DNA of the specified token.
     * @dev This internal function assigns the new DNA value to the token identified by _tokenID
     *      and emits the DnaChanged and MetadataUpdate events to signal the update.
     * @param _tokenID The unique identifier of the token whose DNA is being updated.
     * @param _dna The new DNA value to be assigned to the token.
     */
    function _setDna(uint256 _tokenID, uint256 _dna) internal {
        indexDna[_tokenID] = _dna;
        emit DnaChanged(_tokenID, _dna);
        emit MetadataUpdate(_tokenID);
    }

    /**
     * @notice Retrieves the DNA value associated with a given token ID.
     * @param _tokenID The identifier of the token whose DNA is requested.
     * @return The DNA of the specified token represented as a uint256.
     */
    function getDna(uint256 _tokenID) public view returns (uint256) {
        return indexDna[_tokenID];
    }

 
    /**
     * @dev Sets the new base URI for the NFT contract.
     * This function updates the existing base URI to the provided value and emits
     * a {BaseURIChanged} event indicating the change.
     *
     * Requirements:
     * - The caller must have admin privileges.
     *
     * @param _newURI The new base URI to be set.
     * @return The updated base URI.
     */
    function setBaseURI(string memory _newURI) external onlyAdmin returns (string memory) {
        baseURI = _newURI;
        emit BaseURIChanged(baseURI);
        emit BatchMetadataUpdate(0, _tokenIdCounter); // update all tokens
        return baseURI;
    }

    /**
     * @notice Retrieves the URI for a given token.
     * @dev Constructs the token URI by concatenating the base URI with the token ID converted to a string.
     *      - Reverts if the token does not exist (i.e., if the token's owner is the zero address).
     *      - Returns an empty string if the base URI is not set.
     * @param tokenId The unique identifier for the token.
     * @return string The generated token URI for the specified token ID.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "kNFT: nonexistent token");
        if (bytes(baseURI).length == 0) {
            return "";
        }
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }   

    // -------------------- getKndxForEth (Uniswap) -------------------- //

   
    /**
     * @notice Returns how many KNDX tokens are required for a given amount of ETH in Wei
     *         using the direct Uniswap V2 pair reserves (WETH/KNDX).
     * @dev Formula: 
     *     KNDX_required = (ethAmountWei * reserveKNDX) / reserveWETH
     * @param ethAmountWei The amount of ETH (in Wei) to convert
     * @return The amount of KNDX tokens equivalent to `ethAmountWei` of ETH
     */
    function getKndxForEth(uint256 ethAmountWei) public view returns (uint256) {
        if (ethAmountWei == 0) {
            return 0;
        }

        // 1) Grab the direct WETH-KNDX pair reserves
        (uint112 reserveWETH, uint112 reserveKNDX) = _getReserves();

        // 2) Convert from ETH => KNDX based on the ratio: (ethAmountWei * reserveKNDX) / reserveWETH
        //    If you want to handle safe multiplication/division, you can use OpenZeppelin's Math or a checked approach.
        return (ethAmountWei * reserveKNDX) / reserveWETH;
    }

    /**
     * @notice Retrieves the current liquidity reserves for WETH and KNDX.
     * @dev This function calls getReserves on the uniswapPair contract to obtain the reserves.
     * It then determines the correct mapping of reserve values to WETH and KNDX based on the
     * token order in the pair. Reverts if either reserve is zero.
     *
     * @return reserveWETH The liquidity reserve for the WETH token.
     * @return reserveKNDX The liquidity reserve for the KNDX token.
     */
    function _getReserves() internal view returns (uint112 reserveWETH, uint112 reserveKNDX) {
        // If your contract stores the pair address separately (e.g. `uniswapPair`), do:

        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves(); 
        address token0 = uniswapV2Pair.token0();  

        // We assume `WETH` and `KNDX` are already stored in your contract
        if (token0 == WETH) {
            reserveWETH = reserve0;
            reserveKNDX = reserve1;
        } else {
            reserveWETH = reserve1;
            reserveKNDX = reserve0;
        }

        require(reserveWETH > 0 && reserveKNDX > 0, "Invalid reserves");
    }


    // -------------------- Transfer Hook: _update Override -------------------- //

    
    /**
     * @notice Updates the ownership state of a token.
     * @dev This function overrides the _update functions in both ERC721 and ERC721Enumerable.
     * It determines the operation mode (mint, burn, or transfer) based on the token's current owner
     * and the destination address. If the operation is a transfer (not a mint or burn) and royalty enforcement
     * is enabled, it calls _enforceRoyalty to ensure compliance with royalty rules before proceeding.
     * Finally, it calls the parent _update function to effect the state change.
     *
     * @param to The address of the new owner. A zero address indicates a burn operation.
     * @param tokenId The identifier of the token being updated.
     * @param auth The address of the caller authorized to perform the update.
     * @return prevOwner The previous owner of the token.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address prevOwner)
    {
        address from = _ownerOf(tokenId);
        bool isMint = (from == address(0));
        bool isBurn = (to == address(0));

        // Enforce royalty
        if (!isMint && !isBurn && royaltyEnforcementEnabled) {
            _enforceRoyalty(from, tokenId);
        }

        // Now perform the actual update
        prevOwner = super._update(to, tokenId, auth);

        // If it is a true transfer (from != to, ignoring mints/burns), clear user info
        if (!isMint && !isBurn && from != to) {
            // Clear EIP-4907 user info upon a normal transfer
            if (_users[tokenId].user != address(0)) {
                delete _users[tokenId];
                emit UpdateUser(tokenId, address(0), 0);
            }
        }
    }

    /**
     * @notice Enforces royalty payments for a token transfer by converting ETH-based royalties to KNDX tokens.
     * @dev Checks if the sender is exempt from paying royalties due to being the minter or holding a founder pass.
     * If not exempt, it calculates the required amount of KNDX tokens for the ETH royalty, ensuring the conversion is successful.
     * Depending on whether the treasury fee is enabled, it splits the royalty payment between the treasury and the royalty owner,
     * transferring the appropriate amounts via ERC20 transferFrom calls.
     *
     * @param from The address initiating the token transfer.
     * @param tokenId The identifier of the token whose royalty is being enforced.
     *
     * Requirements:
     * - If a non-zero ETH royalty is set for the token, the conversion to KNDX must yield a positive value.
     * - The ERC20 transferFrom calls for royalty payments (and treasury cut if enabled) must succeed.
     */
    function _enforceRoyalty(address from, uint256 tokenId) internal {
        uint256 ethRoyalty = royaltyETHWei[tokenId];
        if (ethRoyalty == 0) return;

        bool isMinterExempt  = (mintedOwnerExemptEnabled && from == royaltyOwnerOf[tokenId]);
        bool isFounderExempt = (founderPassExemptEnabled && foundersPass.balanceOf(from) > 0);
        if (isMinterExempt || isFounderExempt) return;

        uint256 requiredKndx = getKndxForEth(ethRoyalty);
        require(requiredKndx > 0, "Royalty calc failed");

        IERC20 kndxToken = IERC20(KNDX);

        // partner wallet (falls back to creator if unset)
        address _partner = (partnerWallet != address(0))
            ? partnerWallet
            : royaltyOwnerOf[tokenId];

        // compute splits
        uint256 amountManufacturer = treasuryFeeEnabled
            ? (requiredKndx * manufacturerCutBP) / denominator
            : 0;
        uint256 amountPartner = (requiredKndx * partnerCutBP) / denominator;
        uint256 amountCreator = requiredKndx - amountManufacturer - amountPartner;

        require(
            kndxToken.allowance(from, address(this)) >= requiredKndx,
            "Insufficient allowance for royalty transfer"
        );

        // transfers
        if (amountManufacturer > 0) {
            require(
                kndxToken.transferFrom(from, konduxTreasury, amountManufacturer),
                "Royalty: manufacturer"
            );
        }
        require(
            kndxToken.transferFrom(from, _partner, amountPartner),
            "Royalty: partner"
        );
        require(
            kndxToken.transferFrom(from, royaltyOwnerOf[tokenId], amountCreator),
            "Royalty: creator"
        );
    }


    // -------------------- DNA Gene Reading/Writing -------------------- //

    /**
     * @notice Extracts a range of bytes from the DNA of a token.
     * @dev Reads the stored 256-bit DNA value for a given token and extracts bytes in the range 
     *      [startIndex, endIndex] by iterating through each byte, shifting, masking, and accumulating 
     *      them into a new integer value. The extraction is performed in a big-endian manner by 
     *      reversing the byte index.
     *
     * Requirements:
     * - `startIndex` must be less than `endIndex` and `endIndex` must be at most 32.
     * - The token corresponding to `_tokenID` must exist (its owner must not be the zero address).
     *
     * @param _tokenID The unique identifier of the token.
     * @param startIndex The starting index (inclusive) for the byte range to extract.
     * @param endIndex The ending index (exclusive) for the byte range to extract.
     * @return int256 The integer value compiled from the extracted byte range.
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
            assembly {
                // Big-endian byte position in the 256-bit DNA
                let bytePos := sub(31, i)
                let shiftAmount := mul(8, bytePos)
                
                // Extract the single byte from 'originalValue'
                let extractedByte := and(shr(shiftAmount, originalValue), 0xff)

                // If we want the extracted result to remain in big-endian order,
                // we match the logic in _writeGen:
                //   'i = startIndex' => highest position in the final extractedValue
                //   'i = endIndex - 1' => lowest position
                // So the offset within 'extractedValue' is: 
                //   8 * ( (endIndex - 1) - i )
                let adjustedShiftAmount := mul(8, sub(sub(endIndex, 1), i))

                extractedValue := or(
                    extractedValue,
                    shl(adjustedShiftAmount, extractedByte)
                )
            }
        }

        return int256(extractedValue);
    }


    /**
     * @notice Writes generation data for a specific token.
     * @dev This function can only be called by accounts with the DNA modifier role.
     * @param _tokenID The unique identifier of the token.
     * @param inputValue The value representing the genetic data to write.
     * @param startIndex The starting index of the genetic data segment.
     * @param endIndex The ending index of the genetic data segment.
     */
    function writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex)
        public
        onlyDnaModifier
    {
        _writeGen(_tokenID, inputValue, startIndex, endIndex);
    }

    /**
     * @notice Updates a segment of a token's DNA data with a new value.
     * @dev Extracts bytes from `inputValue` covering the byte range [startIndex, endIndex) and writes them into the token's DNA.
     *      The function first builds a mask over the specified byte range, extracts each corresponding byte from `inputValue`,
     *      shifts it into the correct position, and then updates the token's DNA by combining the untouched bytes with the new bytes.
     *      It requires that the token exists and that `inputValue` fits within the specified byte range.
     * @param _tokenID The identifier of the token whose DNA is being modified.
     * @param inputValue The value that contains the new DNA segment; must be within the bit-width for (endIndex - startIndex) bytes.
     * @param startIndex The starting byte index (inclusive) for the DNA segment to update; must be < `endIndex`.
     * @param endIndex The ending byte index (exclusive) for the DNA segment update; must be no greater than 32.
     */
    function _writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex)
        internal
    {
        require(startIndex < endIndex && endIndex <= 32, "kNFT: Invalid range");
        require(_ownerOf(_tokenID) != address(0), "kNFT: nonexistent token");

        uint256 maxInputValue = (1 << ((endIndex - startIndex) * 8)) - 1;
        require(inputValue <= maxInputValue, "kNFT: Input too large");

        uint256 originalValue = indexDna[_tokenID];
        uint256 mask;
        uint256 updatedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            /* 
            * We place the updated byte in a "big-endian" location for the final 256-bit word,
            * but read the bytes from inputValue in big-endian order as well.
            * If endIndex - startIndex = 2 and inputValue = 0xbeef, then:
            *  - On i = startIndex (say, 0), we shift inputValue by 8 to extract 0xbe
            *  - On i = startIndex+1 (1), we shift by 0 to extract 0xef
            */
            assembly {
                // Where to place it in the 256-bit word (big-endian offset)
                let bytePos := sub(31, i)
                let shiftAmount := mul(8, bytePos)

                // Build the mask for this byte
                mask := or(mask, shl(shiftAmount, 0xff))

                // Read the correct byte from inputValue in big-endian order
                // Instead of sub(i, startIndex), we invert the read so 0xbe is written first, then 0xef
                let readOffset := mul(8, sub(sub(endIndex, 1), i))
                let extractedByte := and(shr(readOffset, inputValue), 0xff)

                // Shift that byte into position and OR into updatedValue
                updatedValue := or(updatedValue, shl(shiftAmount, extractedByte))
            }
        }

        // Clear the old bytes in this range, then store the updated bytes
        indexDna[_tokenID] = (originalValue & ~mask) | (updatedValue & mask);

        emit DnaModified(_tokenID, indexDna[_tokenID], inputValue, startIndex, endIndex);
        emit MetadataUpdate(_tokenID);
    }


    // -------------------- Access Control Adjustments -------------------- //

    /**
     * @notice Sets or revokes a role for a given address.
     * @dev Grants the role if 'enabled' is true, otherwise revokes the role.
     * The function emits a RoleChanged event after the operation.
     * @param role The role identifier (bytes32) to be assigned or revoked.
     * @param addr The address for which the role will be modified.
     * @param enabled A boolean flag indicating whether to grant (true) or revoke (false) the role.
     *
     * Requirements:
     * - The caller must be an admin (as enforced by the onlyAdmin modifier).
     */
    function setRole(bytes32 role, address addr, bool enabled) public onlyAdmin {
        if (enabled) {
            _grantRole(role, addr);
        } else {
            _revokeRole(role, addr);
        }
        emit RoleChanged(addr, role, enabled);
    }

    // -------------------- EIP-4906: Metadata Update Support -------------------- //

    /**
     * @notice Checks if the contract implements the interface defined by `interfaceId`.
     * @dev This implementation includes support for the EIP-4906 interface (ID: 0x49064906) in addition to
     *      the interfaces supported by parent contracts as determined by the `super.supportsInterface(interfaceId)` calls.
     * @param interfaceId The interface identifier, as defined in ERC-165.
     * @return bool Returns true if the contract supports the requested interface, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, ERC721Royalty, AccessControl, IERC165)
        returns (bool)
    {
        // EIP-4906 (metadata update) => 0x49064906
        // EIP-4907 (rentals)         => 0xad092b5c
        return
            interfaceId == 0x49064906 ||
             // Only claim 4907 support if enabled
            (eip4907Enabled && interfaceId == 0xad092b5c) ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Emits a MetadataUpdate event for a given token.
     * @dev Only an admin can call this function. It validates that the token exists before emitting the event.
     * @param tokenId The unique identifier of the token to be updated.
     */
    function emitMetadataUpdate(uint256 tokenId) external onlyAdmin {
        require(_ownerOf(tokenId) != address(0), "kNFT: nonexistent token");
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice Emits a BatchMetadataUpdate event for a given range of token IDs.
     * @dev Reverts if the starting token ID is greater than the ending token ID.
     *      This function can only be called by an admin.
     * @param fromTokenId The starting token ID of the range.
     * @param toTokenId The ending token ID of the range.
     */
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) external onlyAdmin {
        require(fromTokenId <= toTokenId, "kNFT: invalid range");
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    // -------------------- EIP-4907: setUser, userOf, userExpires -------------------- //

    /**
     * @notice Set or update the user address and its expiration for a token.
     * @dev This function is part of EIP-4907. It can be `public` or `external`.
     *      Reverts if `tokenId` does not exist or if caller is not owner/approved.
     * @param tokenId The token whose user data is being changed
     * @param user The new user address (zero means no user)
     * @param expires Unix timestamp of the expiration date for the user
     */
    function setUser(uint256 tokenId, address user, uint64 expires) external override {
        // Standard EIP-4907 pattern: owner or approved can set the user role
        // require owner or authorized
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC4907: nonexistent token");
        require(user != address(0), "ERC4907: user cannot be zero address");
        // Check if the caller is the owner or has approval
        // This is a common pattern in ERC721 to check ownership or approval
        require(_ownerOf(tokenId) == msg.sender || _isAuthorized(_ownerOf(tokenId), msg.sender, tokenId), "ERC4907: not owner nor approved");

        _users[tokenId].user = user;
        _users[tokenId].expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    /**
     * @notice Get the user address of a token (if any).
     * @dev Returns address(0) if no user or user is expired.
     * @param tokenId The token to query for user info.
     */
    function userOf(uint256 tokenId) public view override returns (address) {
        if (!eip4907Enabled) return address(0);
        if (block.timestamp <= _users[tokenId].expires) {
            return _users[tokenId].user;
        }
        return address(0);
    }

    /**
     * @notice Get the expiration timestamp of the current user role.
     * @dev Returns 0 if no user is set.
     * @param tokenId The token to query for user expiration.
    */
    function userExpires(uint256 tokenId) public view override returns (uint256) {
        return _users[tokenId].expires;
    }

    // -------------------- Emergency Withdrawal -------------------- //

    /**
     * @notice Withdraws a specified amount of tokens from the contract in an emergency scenario.
     * @dev Can only be executed by an admin. This function attempts to transfer the specified
     *      ERC20 tokens to the provided address using the token's transfer function.
     * @param token The ERC20 token interface representing the token to be withdrawn.
     * @param to The address that will receive the withdrawn tokens; must not be the zero address.
     * @param amount The amount of tokens to withdraw.
     * @dev Reverts if the recipient address is the zero address or if the token transfer fails.
     */
    function emergencyWithdrawToken(IERC20 token, address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        require(token.transfer(to, amount), "kNFT: transfer failed");
    }

    /**
     * @notice Allows an admin to extract a specific NFT from the contract.
     * @dev Transfers the NFT identified by tokenId from the contract to the provided address.
     *      Reverts if the destination address is the zero address.
     * @param nft The ERC721 token interface representing the NFT to be withdrawn.
     * @param to The recipient address for the NFT.
     * @param tokenId The identifier for the NFT to be transferred.
     */
    function emergencyWithdrawNFT(IERC721 nft, address to, uint256 tokenId) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        nft.transferFrom(address(this), to, tokenId);
    }

    // -------------------- Enumerability Overrides -------------------- //

    /**
     * @notice Increases the balance of the specified account by the provided value.
     * @dev This function overrides the _increaseBalance method in both ERC721 and ERC721Enumerable.
     * It ensures that balance management remains consistent across inherited contracts.
     *
     * @param account The address whose balance will be increased.
     * @param value The amount to add to the account's existing balance.
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    // ------------------ Prevent Direct ETH Transfers ------------------ //

    /**
     * @dev Prevents the contract from receiving ETH directly.
     * 
     * This fallback function reverts any ETH transfers made without invoking an intended function.
     * It safeguards against accidental direct deposits of ETH by reverting the transaction
     * with the error message "No direct ETH deposits".
     */
    receive() external payable {
        revert("No direct ETH deposits");
    }

    /**
     * @notice Prevents any plain Ether transfers or unrecognized function calls.
     * @dev The fallback function is declared as payable, but will revert any call to it.
     * This helps ensure that all interactions with the contract use a defined function signature,
     * avoiding unintended behavior or accidental Ether reception.
     */
    fallback() external payable {
        revert("Fallback not permitted");
    }
}
