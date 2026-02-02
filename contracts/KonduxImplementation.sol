// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// -----------------------------------------------------------------------------
// OpenZeppelin (upgradeable) imports
// -----------------------------------------------------------------------------
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// -----------------------------------------------------------------------------
// Limit Break Creator Token Standards imports
// -----------------------------------------------------------------------------
import "contracts/vendor/limitbreak/interfaces/ITransferValidator.sol";
import "contracts/vendor/limitbreak/interfaces/ICreatorToken.sol";
import "contracts/vendor/limitbreak/interfaces/ICreatorTokenLegacy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/interfaces/IERC4906.sol";

import "./interfaces/IERC4907.sol";
import "./interfaces/ICreatorTokenTransferValidator.sol";
import "./interfaces/IKonduxRoyaltySplitter.sol";

/**
 * @title KonduxImplementation
 * @notice Implementation logic for Kondux kNFT collections supporting the
 *         ERC721C creator token standard.  This contract is designed to be
 *         deployed once and cloned via EIP‑1167 minimal proxies.  Each
 *         clone maintains its own royalty configuration and transfer
 *         validator settings independent of the original implementation.
 */
contract KonduxImplementation is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC2981Upgradeable,
    AccessControlEnumerableUpgradeable,
    IERC4906,
    IERC4907,
    ICreatorToken
{
    /*----------------------------------------------------------------------*/
    /*                               Roles                                  */
    /*----------------------------------------------------------------------*/
    bytes32 public constant MINTER_ROLE       = keccak256("MINTER_ROLE");
    bytes32 public constant DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");

    /*----------------------------------------------------------------------*/
    /*                                State                                 */
    /*----------------------------------------------------------------------*/
    // ─── Toggle for EIP‑4907 functionality ────────────────────────────────
    bool public eip4907Enabled;

    // ─── Collection configuration ─────────────────────────────────────────
    uint256 public maxSupply;
    string  public baseURI;
    bool    public freeMinting;
    uint256 private _tokenIdCounter;

    // ─── DNA management ───────────────────────────────────────────────────
    mapping(uint256 => uint256) public indexDna;

    // ─── EIP‑4907 user information ────────────────────────────────────────
    struct UserInfo { address user; uint64 expires; }
    mapping(uint256 => UserInfo) private _users;

    // ─── Creator token (ERC721C) state ─────────────────────────────────────
    /// @dev Address of the collection transfer validator.  If zero and not
    /// explicitly initialized, the default validator will be returned.
    address private _transferValidator;

    /// @dev Indicates if a transfer validator has been explicitly initialized.
    bool private _isTransferValidatorInitialized;

    /// @dev If true, the transfer validator is automatically approved to
    /// transfer tokens on behalf of owners.
    bool public autoApproveTransfersFromValidator;

    /// @dev Default transfer validator address specified by Limit Break.
    /// V5 validator with enhanced security policies and OpenSea support.
    /// Reference: https://apptokens.com/docs/integration-guide/creator-token-standards/v5/contract-deployments
    address public constant DEFAULT_TRANSFER_VALIDATOR =
        0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    // ─── Royalty split bookkeeping ────────────────────────────────────────
    /// @dev Denominator used for basis point calculations.  Defaults to
    /// 10_000 (10000 = 100%).  Can be updated per collection.
    uint96 public denominator;

    /// @dev Basis points allocated to the manufacturer.
    uint96 public manufacturerCutBP;

    /// @dev Basis points allocated to the partner.
    uint96 public partnerCutBP;

    /// @dev Basis points allocated to the creator/minter.
    uint96 public creatorCutBP;

    /// @dev Optional partner wallet used to receive royalty proceeds.
    address public partnerWallet;

    /// @dev The list ID used for the validator whitelist/blacklist.
    uint48 public listId;

    /// @dev Address of the royalty splitter contract for this collection.
    address public royaltySplitter;

    /*----------------------------------------------------------------------*/
    /*                                Events                                */
    /*----------------------------------------------------------------------*/
    event BaseURIChanged(string baseURI);
    event DnaChanged(uint256 indexed tokenID, uint256 dna);
    event DnaModified(uint256 indexed tokenID, uint256 dna, uint256 inputVal, uint8 start, uint8 end);
    event RoleChanged(address indexed who, bytes32 role, bool enabled);
    event FreeMintingChanged(bool enabled);
    // event TransferValidatorUpdated(address indexed oldValidator, address indexed newValidator); // Defined in ICreatorToken
    event AutomaticApprovalOfTransferValidatorSet(bool autoApproved);
    event RoyaltySplitsChanged(uint96 manufacturerCutBP, uint96 partnerCutBP, uint96 creatorCutBP);
    event PartnerWalletChanged(address partner);
    event RoyaltySplitterUpdated(address indexed splitter);
    event CreatorAutoRegistered(uint256 indexed tokenId, address indexed creator);

    /*----------------------------------------------------------------------*/
    /*                           Initialiser                                */
    /*----------------------------------------------------------------------*/
    /**
     * @dev Replaces the constructor.  Must be called exactly once on each clone.
     * @param _name        Collection name
     * @param _symbol      Collection symbol
     * @param _maxSupply   Maximum supply of tokens (0 for unlimited)
     * @param _initialAdmin Address to receive admin roles
     * @param _factory     Optional factory address to grant temporary admin for security setup (zero to skip)
     * @param _royaltySplitter Optional royalty splitter address to set as ERC2981 receiver (zero to use _initialAdmin)
     */
    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _maxSupply,
        address _initialAdmin,
        address _factory,
        address _royaltySplitter
    ) external initializer {
        // Initialize parent contracts
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC721Burnable_init();
        __ERC2981_init();
        __AccessControlEnumerable_init();

        // Grant roles to initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(MINTER_ROLE,         _initialAdmin);
        _grantRole(DNA_MODIFIER_ROLE,   _initialAdmin);

        // Grant factory admin role for initial security configuration (if provided)
        if (_factory != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, _factory);
        }

        // Configure collection parameters
        maxSupply   = _maxSupply;
        eip4907Enabled = true;
        freeMinting    = false;

        // Initialize royalty denominator and default splits (5/0/5 = 10% total)
        denominator        = 10_000;
        manufacturerCutBP  = 500;
        partnerCutBP       = 0;
        creatorCutBP       = 500;

        // Set royalty receiver: use splitter if provided, otherwise initial admin
        uint96 totalRoyalty = manufacturerCutBP + partnerCutBP + creatorCutBP;
        if (_royaltySplitter != address(0)) {
            royaltySplitter = _royaltySplitter;
            _setDefaultRoyalty(_royaltySplitter, totalRoyalty);
            emit RoyaltySplitterUpdated(_royaltySplitter);
        } else {
            _setDefaultRoyalty(_initialAdmin, totalRoyalty);
        }
    }

    /*----------------------------------------------------------------------*/
    /*                      Administration Functions                         */
    /*----------------------------------------------------------------------*/
    /**
     * @dev Restricts access to admin-only functions.  Reverts if caller is not an admin.
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "kNFT: only admin");
        _;
    }

    /**
     * @notice Enables or disables the EIP‑4907 functionality.  When disabled,
     *         calls to setUser() will revert and userOf() will return address(0).
     * @param enabled  Whether to enable (true) or disable (false) the rental API.
     */
    function setEip4907Enabled(bool enabled) external onlyAdmin {
        eip4907Enabled = enabled;
    }

    /**
     * @notice Updates whether minting is free.  When free minting is disabled,
     *         only addresses with the MINTER_ROLE may mint tokens.
     * @param _freeMinting  True to enable free minting, false to restrict minting.
     */
    function setFreeMinting(bool _freeMinting) external onlyAdmin {
        freeMinting = _freeMinting;
        emit FreeMintingChanged(_freeMinting);
    }

    /**
     * @notice Sets the collection's transfer validator.  A zero address
     *         removes any custom validator and falls back to the default.
     * @param validator  Address of the transfer validator contract.
     */
    function setTransferValidator(address validator) external override(ICreatorToken) onlyAdmin {
        address oldValidator = getTransferValidator();
        _transferValidator = validator;
        _isTransferValidatorInitialized = true;
        emit TransferValidatorUpdated(oldValidator, validator);
    }

    /**
     * @notice Returns the address of the transfer validator in use by this collection.
     *         If no validator has been explicitly set, the default validator is returned.
     */
    function getTransferValidator() public view override(ICreatorToken) returns (address validator) {
        validator = _transferValidator;
        if (validator == address(0)) {
            if (!_isTransferValidatorInitialized) {
                validator = DEFAULT_TRANSFER_VALIDATOR;
            }
        }
    }

    /**
     * @notice Returns the function selector and view flag for the validator's
     *         validateTransfer function.  This allows off‑chain simulation of
     *         the validator when integrating with external tools.
     */
    function getTransferValidationFunction() external pure override returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /**
     * @notice Enables or disables automatic approval of the transfer validator.
     *         When enabled, the validator will be automatically approved as an
     *         operator for all token holders.
     * @param autoApprove  True to enable automatic approval, false to disable.
     */
    function setAutomaticApprovalOfTransfersFromValidator(bool autoApprove) external onlyAdmin {
        autoApproveTransfersFromValidator = autoApprove;
        emit AutomaticApprovalOfTransferValidatorSet(autoApprove);
    }

    /**
     * @notice Sets the royalty split basis points for manufacturer, partner and creator.
     *         The sum of the provided values must equal the denominator.
     * @param _manufacturerCutBP  Basis points allocated to the manufacturer.
     * @param _partnerCutBP       Basis points allocated to the partner.
     * @param _creatorCutBP       Basis points allocated to the creator/minter.
     */
    function setRoyaltySplits(uint96 _manufacturerCutBP, uint96 _partnerCutBP, uint96 _creatorCutBP) external onlyAdmin {
        require(
            _manufacturerCutBP + _partnerCutBP + _creatorCutBP <= denominator,
            "kNFT: total royalty splits must not exceed denominator"
        );
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP      = _partnerCutBP;
        creatorCutBP      = _creatorCutBP;
        emit RoyaltySplitsChanged(_manufacturerCutBP, _partnerCutBP, _creatorCutBP);
        // Update default royalty receiver to partnerWallet (if set) or admin,
        // with total royalty numerator equal to the sum of splits.  This makes
        // the ERC2981 royalty reflect the configured total share.
        address receiver = partnerWallet != address(0) ? partnerWallet : getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _setDefaultRoyalty(receiver, _manufacturerCutBP + _partnerCutBP + _creatorCutBP);
    }

    /**
     * @notice Configures the default security policy for the collection.
     *         Creates a new whitelist, adds Seaport 1.6, applies it, and sets security level to 3.
     */
    function setToDefaultSecurityPolicy() external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        
        // Cast to extended interface
        ICreatorTokenTransferValidator v = ICreatorTokenTransferValidator(validator);
        
        // Create a new list for this collection
        listId = v.createList("Kondux Default Whitelist");
        
        // Add Seaport 1.6
        address[] memory accounts = new address[](1);
        accounts[0] = 0x0000000000000068F116a894984e2DB1123eB395; // Seaport 1.6
        v.addAccountsToList(listId, 1, accounts); // 1 = Whitelist
        
        // Apply List
        v.applyListToCollection(address(this), listId);
        
        // Set Level 4 (Operator Whitelist)
        v.setRulesetOfCollection(
            address(this), 
            4, // Ruleset 4 (Operator Whitelist)
            address(0), 
            0, 
            0
        );
    }

    /**
     * @notice Adds accounts to the collection's whitelist.
     * @param accounts  Array of addresses to whitelist.
     */
    function addAccountsToWhitelist(address[] calldata accounts) external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        require(listId != 0, "kNFT: list not initialized");
        ICreatorTokenTransferValidator(validator).addAccountsToList(listId, 1, accounts);
    }

    /**
     * @notice Adds accounts to the collection's authorizer list.
     *         Authorizers can call beforeAuthorizedTransfer on the transfer validator
     *         to pre-approve transfers (required by OpenSea's SignedZone for ERC721C).
     * @param accounts  Array of addresses to authorize.
     */
    function addAccountsToAuthorizers(address[] calldata accounts) external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        require(listId != 0, "kNFT: list not initialized");
        ICreatorTokenTransferValidator(validator).addAccountsToList(listId, 2, accounts);
    }

    /**
     * @notice Removes accounts from the collection's authorizer list.
     * @param accounts  Array of addresses to deauthorize.
     */
    function removeAccountsFromAuthorizers(address[] calldata accounts) external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        require(listId != 0, "kNFT: list not initialized");
        ICreatorTokenTransferValidator(validator).removeAccountsFromList(listId, 2, accounts);
    }

    /**
     * @notice Adds accounts to the collection's blacklist.
     * @param accounts  Array of addresses to blacklist.
     */
    function addAccountsToBlacklist(address[] calldata accounts) external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        require(listId != 0, "kNFT: list not initialized");
        ICreatorTokenTransferValidator(validator).addAccountsToList(listId, 0, accounts);
    }

    /**
     * @notice Freezes accounts for this collection, preventing them from transferring or receiving tokens.
     *         Requires account freezing mode to be enabled in the security policy.
     * @param accounts  Array of addresses to freeze.
     */
    function freezeAccounts(address[] calldata accounts) external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        ICreatorTokenTransferValidator(validator).freezeAccountsForCollection(address(this), accounts);
    }

    /**
     * @notice Unfreezes accounts for this collection.
     * @param accounts  Array of addresses to unfreeze.
     */
    function unfreezeAccounts(address[] calldata accounts) external onlyAdmin {
        address validator = getTransferValidator();
        require(validator != address(0), "kNFT: validator not set");
        ICreatorTokenTransferValidator(validator).unfreezeAccountsForCollection(address(this), accounts);
    }

    /**
     * @notice Sets the partner wallet used to receive partner royalties.  The
     *         partner wallet is also used as the default receiver for ERC2981
     *         royalties if set.
     * @param _partner  Address of the partner wallet.  Use zero address to
     *         disable partner wallet usage.
     */
    function setPartnerWallet(address _partner) external onlyAdmin {
        partnerWallet = _partner;
        emit PartnerWalletChanged(_partner);
        // Update default royalty receiver when partnerWallet is changed.
        address receiver = _partner != address(0) ? _partner : getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _setDefaultRoyalty(receiver, manufacturerCutBP + partnerCutBP + creatorCutBP);
    }

    /**
     * @notice Changes the denominator used for royalty calculations.  Changing
     *         the denominator will not automatically adjust existing splits.
     *         Call setRoyaltySplits() after changing the denominator to
     *         reconfigure the splits.
     * @param _denominator  New denominator value.
     * @return              The updated denominator.
     */
    function changeDenominator(uint96 _denominator) external onlyAdmin returns (uint96) {
        require(_denominator > 0, "kNFT: denominator must be > 0");
        denominator = _denominator;
        return denominator;
    }

    /**
     * @notice Sets the default royalty using the ERC‑2981 standard.
     * @dev    The sum of the royalty fee numerator must not exceed the denominator (10000 for basis points).
     * @param receiver     Address that will receive the royalty.
     * @param feeNumerator Royalty fee numerator (denominator defaults to 10000).
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyAdmin {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @notice Deletes the default royalty configured via ERC‑2981.
     */
    function deleteDefaultRoyalty() external onlyAdmin {
        _deleteDefaultRoyalty();
    }

    /**
     * @notice Sets a token‑specific royalty using the ERC‑2981 standard.
     * @param tokenId      Token ID to configure.
     * @param receiver     Address that will receive the royalty.
     * @param feeNumerator Royalty fee numerator (denominator defaults to 10000).
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyAdmin {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @notice Sets the royalty splitter contract and updates ERC2981 receiver.
     * @dev Can be called once by anyone if not yet configured (for factory deployment),
     *      or by admin to update/clear the splitter.
     * @param _splitter Address of KonduxRoyaltySplitter (or zero to disable).
     */
    function setRoyaltySplitter(address _splitter) external {
        // Allow one-time setup by anyone if not yet configured (for factory deployment)
        // After that, only admins can change it
        if (royaltySplitter != address(0)) {
            require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "kNFT: only admin");
        }

        royaltySplitter = _splitter;

        if (_splitter != address(0)) {
            // Update ERC2981 to point to the splitter as the royalty receiver
            uint96 totalRoyalty = manufacturerCutBP + partnerCutBP + creatorCutBP;
            _setDefaultRoyalty(_splitter, totalRoyalty);
        }

        emit RoyaltySplitterUpdated(_splitter);
    }

    /**
     * @notice Returns the creator address for a token from the royalty splitter.
     * @param tokenId The token ID to query.
     * @return creator The creator's address (zero if not registered or no splitter).
     */
    function getCreator(uint256 tokenId) external view returns (address creator) {
        if (royaltySplitter == address(0)) {
            return address(0);
        }
        (creator, ) = IKonduxRoyaltySplitter(royaltySplitter).getCreatorInfo(tokenId);
    }

    /*----------------------------------------------------------------------*/
    /*                      Minting & DNA Management                        */
    /*----------------------------------------------------------------------*/
    /**
     * @dev Restricts access to minting functions.  When freeMinting is false,
     *      only addresses with the MINTER_ROLE may mint.
     */
    modifier onlyMinter() {
        if (!freeMinting) {
            require(hasRole(MINTER_ROLE, msg.sender), "kNFT: only minter");
        }
        _;
    }

    /**
     * @dev Restricts access to DNA modification functions.  Only addresses
     *      granted the DNA_MODIFIER_ROLE may call functions with this modifier.
     */
    modifier onlyDnaModifier() {
        require(hasRole(DNA_MODIFIER_ROLE, msg.sender), "kNFT: only dna modifier");
        _;
    }

    /**
     * @notice Mints a new token with the specified DNA.  If maxSupply is
     *         non‑zero, ensures the supply cap is not exceeded.  Auto-registers
     *         the recipient as the creator in the royalty splitter if configured.
     * @param to   Address to receive the minted token (also registered as creator).
     * @param dna  Unique DNA value associated with the token.
     * @return     The minted token ID.
     */
    function safeMint(address to, uint256 dna) public onlyMinter returns (uint256) {
        require(maxSupply == 0 || _tokenIdCounter < maxSupply, "Max supply reached");
        uint256 tokenId = _tokenIdCounter++;
        _setDna(tokenId, dna);
        _safeMint(to, tokenId);

        // Auto-register recipient as creator (can be overridden by admin/distributor later)
        if (royaltySplitter != address(0)) {
            try IKonduxRoyaltySplitter(royaltySplitter).registerCreator(
                tokenId,
                to,              // Recipient is the creator
                creatorCutBP     // Use collection's default creator cut
            ) {
                emit CreatorAutoRegistered(tokenId, to);
            } catch {
                // Silently fail if splitter rejects (e.g., already registered)
            }
        }

        return tokenId;
    }

    /**
     * @notice Mints a new token with explicit creator address for royalties.
     * @param to                 Address to receive the minted token.
     * @param dna                Unique DNA value associated with the token.
     * @param creator            Explicit creator address for royalties.
     * @param customCreatorCutBP Custom creator cut in basis points (0 to use default).
     * @return                   The minted token ID.
     */
    function safeMintWithCreator(
        address to,
        uint256 dna,
        address creator,
        uint96 customCreatorCutBP
    ) public onlyMinter returns (uint256) {
        require(maxSupply == 0 || _tokenIdCounter < maxSupply, "Max supply reached");
        uint256 tokenId = _tokenIdCounter++;
        _setDna(tokenId, dna);
        _safeMint(to, tokenId);

        // Register explicit creator if splitter is configured
        if (royaltySplitter != address(0) && creator != address(0)) {
            uint96 cutToUse = customCreatorCutBP > 0 ? customCreatorCutBP : creatorCutBP;
            try IKonduxRoyaltySplitter(royaltySplitter).registerCreator(
                tokenId,
                creator,
                cutToUse
            ) {
                emit CreatorAutoRegistered(tokenId, creator);
            } catch {
                // Silently fail if splitter rejects
            }
        }

        return tokenId;
    }

    /**
     * @notice Assigns a new DNA value to the specified token.
     * @param _tokenID  Token ID to update.
     * @param _dna      New DNA value.
     */
    function setDna(uint256 _tokenID, uint256 _dna) external onlyDnaModifier {
        _setDna(_tokenID, _dna);
    }

    /**
     * @notice Batch assigns new DNA values for multiple tokens.  Both arrays
     *         must be of equal length.
     * @param tokenIDs  Array of token IDs to update.
     * @param dnas      Array of DNA values corresponding to each token.
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
     * @dev Internal helper to set DNA and emit the associated events.
     */
    function _setDna(uint256 _tokenID, uint256 _dna) internal {
        indexDna[_tokenID] = _dna;
        emit DnaChanged(_tokenID, _dna);
        emit MetadataUpdate(_tokenID);
    }

    /**
     * @notice Retrieves the DNA associated with the specified token ID.
     */
    function getDna(uint256 _tokenID) external view returns (uint256) {
        return indexDna[_tokenID];
    }

    /**
     * @notice Sets a new base URI for the collection.  Updates token metadata
     *         for all existing tokens.
     * @param _newURI  The new base URI.
     * @return         The updated base URI.
     */
    function setBaseURI(string memory _newURI) external onlyAdmin returns (string memory) {
        baseURI = _newURI;
        emit BaseURIChanged(baseURI);
        emit BatchMetadataUpdate(0, _tokenIdCounter);
        return baseURI;
    }

    /**
     * @notice Returns the token URI for the specified token ID.  Reverts if
     *         the token does not exist.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "kNFT: nonexistent token");
        if (bytes(baseURI).length == 0) {
            return "";
        }
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    /*----------------------------------------------------------------------*/
    /*                     Transfer Hook Overrides                          */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Overrides the standard ERC721 update hook to insert transfer
     *         validator logic prior to performing the actual transfer.  For
     *         normal transfers (neither mint nor burn), the configured
     *         transfer validator is invoked.  If the validator reverts,
     *         the transfer will be prevented.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address prevOwner)
    {
        address from = _ownerOf(tokenId);
        bool isMint = (from == address(0));
        bool isBurn = (to == address(0));

        // Pre‑validate transfer through external validator for normal transfers
        if (!isMint && !isBurn) {
            address validator = getTransferValidator();
            if (validator != address(0)) {
                // If the validator reverts, the whole transaction will revert
                ITransferValidator(validator).validateTransfer(msg.sender, from, to, tokenId);
            }

            // Register sale with splitter for atomic royalty distribution
            // This allows the splitter to know which token is being sold when it receives ETH
            if (royaltySplitter != address(0)) {
                try IKonduxRoyaltySplitter(royaltySplitter).registerSale(tokenId) {} catch {}
            }
        }

        // Perform the actual update via parent hooks
        prevOwner = super._update(to, tokenId, auth);

        // If it is a normal transfer, clear any existing EIP‑4907 user info
        if (!isMint && !isBurn && from != to) {
            if (_users[tokenId].user != address(0)) {
                delete _users[tokenId];
                emit UpdateUser(tokenId, address(0), 0);
            }
        }
    }

    /**
     * @notice Overrides isApprovedForAll to optionally auto‑approve the transfer
     *         validator as an operator.  If the operator is not already
     *         approved for all and automatic approval is enabled, returns true
     *         for the validator address.
     */
    function isApprovedForAll(address _owner, address operator) public view virtual override(ERC721Upgradeable, IERC721) returns (bool) {
        bool approved = super.isApprovedForAll(_owner, operator);
        if (!approved && autoApproveTransfersFromValidator) {
            if (operator == getTransferValidator()) {
                approved = true;
            }
        }
        return approved;
    }

    /*----------------------------------------------------------------------*/
    /*                   DNA Gene Reading and Writing                       */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Extracts a big‑endian range of bytes from a token's DNA.
     * @param _tokenID    Token ID whose DNA is being read.
     * @param startIndex  Inclusive start index (0 ≤ startIndex < 32).
     * @param endIndex    Exclusive end index (startIndex < endIndex ≤ 32).
     * @return            Extracted integer value from the DNA range.
     */
    function readGen(uint256 _tokenID, uint8 startIndex, uint8 endIndex) external view returns (int256)
    {
        require(startIndex < endIndex && endIndex <= 32, "kNFT: Invalid range");
        require(_ownerOf(_tokenID) != address(0), "kNFT: nonexistent token");

        uint256 originalValue = indexDna[_tokenID];
        uint256 extractedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            assembly {
                // Big‑endian byte position in the 256‑bit DNA
                let bytePos := sub(31, i)
                let shiftAmount := mul(8, bytePos)

                // Extract the single byte from 'originalValue'
                let extractedByte := and(shr(shiftAmount, originalValue), 0xff)

                // Place bytes in big‑endian order in the result
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
     * @notice Assigns a segment of DNA bits from inputValue into the token's DNA.
     * @param _tokenID    Token ID to update.
     * @param inputValue  Data containing the new DNA segment.
     * @param startIndex  Inclusive start index.
     * @param endIndex    Exclusive end index.
     */
    function writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex)
        external
        onlyDnaModifier
    {
        _writeGen(_tokenID, inputValue, startIndex, endIndex);
    }

    /**
     * @dev Internal helper to write generation data into a token's DNA.  Performs
     *      range validation and bit‑wise insertion.
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
            assembly {
                let bytePos := sub(31, i)
                let shiftAmount := mul(8, bytePos)

                // Build the mask for this byte
                mask := or(mask, shl(shiftAmount, 0xff))

                // Read the correct byte from inputValue in big‑endian order
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

    /*----------------------------------------------------------------------*/
    /*                    Access Control Adjustments                        */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Grants or revokes a role for the specified address.
     * @param role    The role identifier.
     * @param addr    The address to modify.
     * @param enabled True to grant the role, false to revoke.
     */
    function setRole(bytes32 role, address addr, bool enabled) external onlyAdmin {
        if (enabled) {
            _grantRole(role, addr);
        } else {
            _revokeRole(role, addr);
        }
        emit RoleChanged(addr, role, enabled);
    }

    /*----------------------------------------------------------------------*/
    /*                    Metadata Update Support                           */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Checks if the contract implements a given interface.  Includes
     *         support for ERC‑2981, ERC‑721C (ICreatorToken), ERC‑4906 and
     *         ERC‑4907 when enabled.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlEnumerableUpgradeable,
            ERC2981Upgradeable,
            IERC165
        )
        returns (bool)
    {
        // ERC‑4906 (Metadata update) => 0x49064906
        // ERC‑4907 (Rentals)         => 0xad092b5c
        if (interfaceId == type(ICreatorToken).interfaceId || interfaceId == type(ICreatorTokenLegacy).interfaceId) {
            return true;
        }
        if (interfaceId == 0x49064906) {
            return true;
        }
        if (eip4907Enabled && interfaceId == 0xad092b5c) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Emits a MetadataUpdate event for a specific token.  Can be
     *         used by admins to manually notify off‑chain services of a
     *         metadata change.
     * @param tokenId  The token ID.
     */
    function emitMetadataUpdate(uint256 tokenId) external onlyAdmin {
        require(_ownerOf(tokenId) != address(0), "kNFT: nonexistent token");
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice Emits a BatchMetadataUpdate event for a range of tokens.
     * @param fromTokenId  Starting token ID.
     * @param toTokenId    Ending token ID.
     */
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) external onlyAdmin {
        require(fromTokenId <= toTokenId, "kNFT: invalid range");
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    /*----------------------------------------------------------------------*/
    /*                EIP‑4907 Rental Functionality                        */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Assigns a temporary user for a token with an expiration.
     * @param tokenId  Token ID to set user for.
     * @param user     Address of the new user.
     * @param expires  Unix timestamp when the user right expires.
     */
    function setUser(uint256 tokenId, address user, uint64 expires) external override {
        require(eip4907Enabled, "ERC4907: disabled");
        address tokenOwner = _ownerOf(tokenId);
        require(tokenOwner != address(0), "ERC4907: nonexistent token");
        require(user != address(0), "ERC4907: user cannot be zero address");
        require(tokenOwner == msg.sender || _isAuthorized(tokenOwner, msg.sender, tokenId), "ERC4907: not owner nor approved");
        _users[tokenId].user = user;
        _users[tokenId].expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    /**
     * @notice Returns the user assigned to a token if the user rights have not expired.
     * @param tokenId  Token ID to query.
     */
    function userOf(uint256 tokenId) public view override returns (address) {
        if (!eip4907Enabled) return address(0);
        if (block.timestamp <= _users[tokenId].expires) {
            return _users[tokenId].user;
        }
        return address(0);
    }

    /**
     * @notice Returns the expiration timestamp of the user rights assigned to a token.
     * @param tokenId  Token ID to query.
     */
    function userExpires(uint256 tokenId) public view override returns (uint256) {
        return _users[tokenId].expires;
    }

    /*----------------------------------------------------------------------*/
    /*                      Emergency Withdrawal                          */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Allows an admin to withdraw ERC20 tokens from the contract.
     * @param token   ERC20 token contract.
     * @param to      Destination address.
     * @param amount  Amount to withdraw.
     */
    function emergencyWithdrawToken(IERC20 token, address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        require(token.transfer(to, amount), "kNFT: transfer failed");
    }

    /**
     * @notice Allows an admin to withdraw an ERC721 token from the contract.
     * @param nft      ERC721 token contract.
     * @param to       Destination address.
     * @param tokenId  Token ID to withdraw.
     */
    function emergencyWithdrawNFT(IERC721 nft, address to, uint256 tokenId) external onlyAdmin {
        require(to != address(0), "kNFT: withdraw to zero");
        nft.transferFrom(address(this), to, tokenId);
    }

    /*----------------------------------------------------------------------*/
    /*                    Enumerability Override                           */
    /*----------------------------------------------------------------------*/
    /**
     * @notice Increases the balance of an account by the specified value.
     * @dev     Override required by multiple inheritance.
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    /*----------------------------------------------------------------------*/
    /*                  Prevent Direct ETH Transfers                       */
    /*----------------------------------------------------------------------*/
    /**
     * @dev Reject direct ETH transfers to this contract.
     */
    receive() external payable {
        revert("No direct ETH deposits");
    }

    /**
     * @dev Reject calls to unknown functions.
     */
    fallback() external payable {
        revert("Fallback not permitted");
    }

    /*----------------------------------------------------------------------*/
    /*                  Storage gap for upgradeability                    */
    /*----------------------------------------------------------------------*/
    uint256[48] private __gap;

    /// @dev Prevent initialization of the implementation itself.
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Returns the address of the current owner (admin).
     * @dev Required for OpenSea Studio compatibility. Returns the first member of DEFAULT_ADMIN_ROLE.
     */
    function owner() public view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }
}