// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KonduxRoyaltySplitter
 * @notice Receives royalty payments from marketplaces and distributes them according to
 *         the Kondux royalty model:
 *
 *         - Manufacturer cut (m): Fixed %, goes to Kondux treasury
 *         - Partner cut (p): Fixed %, goes to partner/collection owner
 *         - Creator cut (c): Variable %, goes to the original minter of the NFT
 *
 *         Creator receives their cut on ALL sales (including first sale).
 *         OpenSea sees a CONSTANT total royalty (m + p + max_c) going to this contract.
 *         This contract then distributes based on per-token creator data.
 *
 *         Supports two modes:
 *         1. PULL MODE: Royalties accumulate, recipients withdraw later
 *         2. PUSH MODE: Atomic distribution during transfer (via onTransferWithValue)
 *
 * @dev This contract should be set as the ERC2981 royalty receiver for the collection.
 */
contract KonduxRoyaltySplitter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant COLLECTION_ROLE = keccak256("COLLECTION_ROLE");
    bytes32 public constant FEE_ADMIN_ROLE = keccak256("FEE_ADMIN_ROLE");

    /// @notice The NFT collection this splitter serves
    /// @dev Can be set once after deployment if initially zero (for factory deployment pattern)
    address public collection;
    
    /// @notice Manufacturer (Kondux) treasury address
    address public manufacturerWallet;
    
    /// @notice Partner/collection owner address  
    address public partnerWallet;
    
    /// @notice Basis points for manufacturer (e.g., 400 = 4%)
    uint96 public manufacturerCutBP;
    
    /// @notice Basis points for partner (e.g., 300 = 3%)
    uint96 public partnerCutBP;
    
    /// @notice Default creator cut for tokens without specific override (e.g., 300 = 3%)
    uint96 public defaultCreatorCutBP;

    /// @notice Default creator wallet for tokens without registered creator
    address public defaultCreatorWallet;

    /// @notice Maximum total royalty (what OpenSea sees as creator_fee)
    uint96 public constant MAX_TOTAL_ROYALTY_BP = 1000; // 10%
    
    uint96 public constant DENOMINATOR = 10000;

    /// @notice Whether to use push (immediate) distribution mode
    bool public pushModeEnabled;

    /// @notice Per-token creator info
    struct CreatorInfo {
        address creator;      // The original minter/creator
        uint96 creatorCutBP;  // Their specific cut in basis points
    }
    
    mapping(uint256 => CreatorInfo) public tokenCreators;
    
    /// @notice Accumulated balances for each recipient
    mapping(address => uint256) public pendingETH;
    mapping(address => mapping(address => uint256)) public pendingERC20; // token => recipient => amount

    /// @notice Events
    event RoyaltyReceived(uint256 indexed tokenId, uint256 amount, address indexed token);
    event RoyaltyDistributed(
        uint256 indexed tokenId,
        uint256 manufacturerAmount,
        uint256 partnerAmount,
        uint256 creatorAmount,
        address indexed creator
    );
    event CreatorRegistered(uint256 indexed tokenId, address indexed creator, uint96 cutBP);
    event WalletsUpdated(address manufacturer, address partner);
    event CutsUpdated(uint96 manufacturerBP, uint96 partnerBP, uint96 defaultCreatorBP);
    event Withdrawn(address indexed recipient, uint256 amount, address indexed token);
    event PushModeUpdated(bool enabled);
    event ImmediateDistribution(
        uint256 indexed tokenId,
        uint256 salePrice,
        uint256 royaltyAmount,
        address indexed seller
    );
    event CreatorWalletUpdated(uint256 indexed tokenId, address indexed oldWallet, address indexed newWallet);
    event CreatorOverridden(uint256 indexed tokenId, address indexed creator, uint96 cutBP);
    event DefaultCreatorWalletUpdated(address indexed newDefaultCreator);
    event CollectionSet(address indexed collection);

    error InvalidAddress();
    error NotCreatorOfToken();
    error AlreadyRegistered();
    error InvalidCuts();
    error TokenNotRegistered();
    error NoFundsToWithdraw();
    error OnlyCollection();
    error TransferFailed();

    constructor(
        address _collection,
        address _manufacturerWallet,
        address _partnerWallet,
        uint96 _manufacturerCutBP,
        uint96 _partnerCutBP,
        uint96 _defaultCreatorCutBP,
        address _defaultCreatorWallet,
        address _admin
    ) {
        // Allow _collection to be zero for factory deployment pattern (set later via setCollection)
        if (_manufacturerWallet == address(0) || _admin == address(0)) {
            revert InvalidAddress();
        }
        if (_manufacturerCutBP + _partnerCutBP + _defaultCreatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }

        collection = _collection;
        manufacturerWallet = _manufacturerWallet;
        partnerWallet = _partnerWallet;
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP = _partnerCutBP;
        defaultCreatorCutBP = _defaultCreatorCutBP;
        defaultCreatorWallet = _defaultCreatorWallet;

        // Enable push mode by default
        pushModeEnabled = true;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(FEE_ADMIN_ROLE, _admin);
        _grantRole(DISTRIBUTOR_ROLE, _admin);
        // Only grant COLLECTION_ROLE if collection is set
        if (_collection != address(0)) {
            _grantRole(COLLECTION_ROLE, _collection);
        }
    }

    /**
     * @notice Set the collection address (can only be called once if initially zero)
     * @dev Used by factory to set collection after deployment in splitter-first pattern
     * @param _collection The NFT collection address
     */
    function setCollection(address _collection) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (collection != address(0)) revert InvalidAddress(); // Already set
        if (_collection == address(0)) revert InvalidAddress();
        
        collection = _collection;
        _grantRole(COLLECTION_ROLE, _collection);
        
        emit CollectionSet(_collection);
    }

    /// @notice Receive ETH (royalty payments)
    /// @dev Uses bidirectional same-block matching to handle Seaport execution order
    receive() external payable {
        if (!pushModeEnabled || msg.value == 0) return;

        // BIDIRECTIONAL MATCHING: Check if a sale was registered in this same block
        // Note: pendingSaleBlock != 0 indicates a pending sale exists (tokenId can be 0)
        if (pendingSaleBlock == block.number && pendingSaleBlock != 0) {
            // Sale was registered first in this block - distribute now
            uint256 tokenId = pendingSaleTokenId;
            uint256 amount = msg.value;

            // Clear state BEFORE distribution (reentrancy protection)
            _clearPendingSaleState();

            _distributeETHImmediate(tokenId, amount);
            emit SameBlockDistribution(tokenId, amount, false); // ethFirst=false, sale came first
            return; // Exit after distribution
        }

        // No matching sale in this block yet - record ETH for later matching
        // If registerSale() is called later in this same block, it will distribute
        pendingETHAmount = msg.value;
        pendingETHBlock = block.number;
    }

    /// @notice Track pending sales for atomic distribution
    /// @dev Maps a unique sale ID to the tokenId being sold
    mapping(bytes32 => uint256) public pendingSales;
    
    /// @notice Counter for generating unique sale IDs
    uint256 public saleNonce;

    /// @notice Last sold token ID for automatic distribution in receive()
    /// @dev Set during registerSale, used by receive() to know which token's royalty is being paid
    uint256 public lastSoldTokenId;

    /// @notice Whether there's a pending sale awaiting payment
    bool public hasPendingSale;

    /*//////////////////////////////////////////////////////////////
                    BIDIRECTIONAL SAME-BLOCK MATCHING
    //////////////////////////////////////////////////////////////*/

    /// @notice Pending ETH amount waiting to be matched with a sale
    uint256 public pendingETHAmount;

    /// @notice Block number when pending ETH was received
    uint256 public pendingETHBlock;

    /// @notice Token ID of pending sale waiting to be matched with ETH
    uint256 public pendingSaleTokenId;

    /// @notice Block number when pending sale was registered
    uint256 public pendingSaleBlock;

    /// @notice Emitted when ETH and sale are matched in the same block
    event SameBlockDistribution(uint256 indexed tokenId, uint256 amount, bool ethFirst);

    /// @dev Clear pending sale state after distribution
    function _clearPendingSaleState() internal {
        pendingSaleTokenId = 0;
        pendingSaleBlock = 0;
        // Also clear legacy state
        hasPendingSale = false;
        lastSoldTokenId = 0;
    }

    /// @dev Clear pending ETH state after distribution
    function _clearPendingETHState() internal {
        pendingETHAmount = 0;
        pendingETHBlock = 0;
    }

    /**
     * @notice Called by the collection contract BEFORE the transfer to register a pending sale
     * @param tokenId The token about to be sold
     * @return saleId A unique identifier for this sale (used to match with incoming payment)
     * @dev Uses bidirectional same-block matching to handle Seaport execution order
     */
    function registerSale(uint256 tokenId) external onlyRole(COLLECTION_ROLE) returns (bytes32 saleId) {
        saleId = keccak256(abi.encodePacked(block.timestamp, tokenId, saleNonce++));
        pendingSales[saleId] = tokenId;

        // BIDIRECTIONAL MATCHING: Check if ETH was received in this same block
        if (pendingETHBlock == block.number && pendingETHAmount > 0) {
            // ETH arrived first in this block - distribute now
            uint256 amount = pendingETHAmount;

            // Clear state BEFORE distribution (reentrancy protection)
            _clearPendingETHState();

            _distributeETHImmediate(tokenId, amount);
            emit SameBlockDistribution(tokenId, amount, true); // ethFirst=true
        } else {
            // No matching ETH in this block yet - record sale for later matching
            // If receive() is called later in this same block, it will distribute
            pendingSaleTokenId = tokenId;
            pendingSaleBlock = block.number;

            // Also set legacy state for backwards compatibility
            lastSoldTokenId = tokenId;
            hasPendingSale = true;
        }

        emit SaleRegistered(saleId, tokenId);
    }

    /**
     * @notice Receive payment for a specific sale and distribute immediately
     * @param saleId The unique sale identifier from registerSale()
     * @dev Called by marketplace or wrapper contract with the royalty payment
     */
    function receivePaymentForSale(bytes32 saleId) external payable nonReentrant {
        uint256 tokenId = pendingSales[saleId];
        require(tokenId != 0 || saleId == bytes32(0), "Unknown sale");
        
        if (msg.value > 0) {
            if (pushModeEnabled && tokenId != 0) {
                _distributeETHImmediate(tokenId, msg.value);
            } else {
                _distributeETH(tokenId, msg.value);
            }
        }
        
        // Clear the pending sale
        delete pendingSales[saleId];
    }

    /**
     * @notice Alternative: Receive payment with tokenId directly specified
     * @param tokenId The token that was sold
     * @dev Simpler approach - caller must be trusted (COLLECTION_ROLE or DISTRIBUTOR_ROLE)
     */
    function receivePaymentForToken(uint256 tokenId) external payable nonReentrant {
        require(
            hasRole(COLLECTION_ROLE, msg.sender) || hasRole(DISTRIBUTOR_ROLE, msg.sender),
            "Not authorized"
        );
        
        if (msg.value > 0) {
            if (pushModeEnabled) {
                _distributeETHImmediate(tokenId, msg.value);
            } else {
                _distributeETH(tokenId, msg.value);
            }
        }
    }

    event SaleRegistered(bytes32 indexed saleId, uint256 indexed tokenId);

    /*//////////////////////////////////////////////////////////////
                         TRANSFER HOOK (ATOMIC)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Called by the NFT contract during a transfer to atomically distribute royalties.
     *         This enables "push mode" where royalties are paid immediately during the sale.
     * @param tokenId The token being transferred
     * @param from The seller
     * @param salePrice The sale price (msg.value sent to this function)
     * @dev Only callable by the collection contract. Expects ETH to be sent with the call.
     */
    function onTransferWithValue(
        uint256 tokenId,
        address from,
        uint256 salePrice
    ) external payable onlyRole(COLLECTION_ROLE) nonReentrant {
        if (msg.value == 0) return;
        
        // Calculate royalty based on sale price
        uint256 royaltyAmount = (salePrice * MAX_TOTAL_ROYALTY_BP) / DENOMINATOR;
        
        // Use actual received value (may differ due to rounding)
        uint256 actualAmount = msg.value;
        if (actualAmount > royaltyAmount) {
            actualAmount = royaltyAmount;
        }

        if (pushModeEnabled) {
            // Immediate distribution
            _distributeETHImmediate(tokenId, actualAmount);
        } else {
            // Accumulate for later withdrawal
            _distributeETH(tokenId, actualAmount);
        }

        emit ImmediateDistribution(tokenId, salePrice, actualAmount, from);
    }

    /**
     * @notice Immediately distribute ETH to recipients (no accumulation)
     */
    function _distributeETHImmediate(uint256 tokenId, uint256 amount) internal {
        (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        ) = _calculateSplit(tokenId, amount);

        // Immediate transfers
        if (manufacturerAmount > 0) {
            _safeTransferETH(manufacturerWallet, manufacturerAmount);
        }
        
        if (partnerWallet != address(0) && partnerAmount > 0) {
            _safeTransferETH(partnerWallet, partnerAmount);
        } else if (partnerAmount > 0) {
            _safeTransferETH(manufacturerWallet, partnerAmount);
        }
        
        if (creator != address(0) && creatorAmount > 0) {
            _safeTransferETH(creator, creatorAmount);
        } else if (creatorAmount > 0) {
            _safeTransferETH(manufacturerWallet, creatorAmount);
        }

        emit RoyaltyDistributed(tokenId, manufacturerAmount, partnerAmount, creatorAmount, creator);
    }

    /**
     * @notice Safe ETH transfer with fallback to pending balance
     */
    function _safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount, gas: 50000}("");
        if (!success) {
            // If transfer fails (e.g., contract without receive), accumulate instead
            pendingETH[to] += amount;
        }
    }

    /**
     * @notice Enable or disable push (immediate) distribution mode
     */
    function setPushMode(bool enabled) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        pushModeEnabled = enabled;
        emit PushModeUpdated(enabled);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register creator info for a token (called by collection on mint or by admin)
     * @param tokenId The token ID
     * @param creator The creator's address
     * @param creatorCutBP The creator's royalty cut in basis points
     * @dev COLLECTION_ROLE can only register new tokens. Admins can override existing.
     */
    function registerCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external {
        // Check authorization
        bool isAdmin = hasRole(ADMIN_ROLE, msg.sender) ||
                       hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
                       hasRole(FEE_ADMIN_ROLE, msg.sender);
        bool isCollection = hasRole(COLLECTION_ROLE, msg.sender);

        require(isAdmin || isCollection, "Not authorized");

        if (creator == address(0)) revert InvalidAddress();
        if (manufacturerCutBP + partnerCutBP + creatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }

        // If already registered, only admins can override (not collection)
        if (tokenCreators[tokenId].creator != address(0)) {
            require(isAdmin, "Already registered, need admin to override");
        }

        tokenCreators[tokenId] = CreatorInfo({
            creator: creator,
            creatorCutBP: creatorCutBP
        });

        emit CreatorRegistered(tokenId, creator, creatorCutBP);
    }

    /**
     * @notice Batch register creators (gas efficient for minting batches)
     * @dev Only admins can batch register (not collection) to prevent abuse
     */
    function registerCreatorsBatch(
        uint256[] calldata tokenIds,
        address[] calldata creators,
        uint96[] calldata creatorCutsBP
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
            hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
            hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(
            tokenIds.length == creators.length && creators.length == creatorCutsBP.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (creators[i] == address(0)) revert InvalidAddress();
            if (manufacturerCutBP + partnerCutBP + creatorCutsBP[i] > MAX_TOTAL_ROYALTY_BP) {
                revert InvalidCuts();
            }

            tokenCreators[tokenIds[i]] = CreatorInfo({
                creator: creators[i],
                creatorCutBP: creatorCutsBP[i]
            });

            emit CreatorRegistered(tokenIds[i], creators[i], creatorCutsBP[i]);
        }
    }

    /**
     * @notice Update wallet addresses
     */
    function setWallets(
        address _manufacturerWallet,
        address _partnerWallet
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        if (_manufacturerWallet == address(0)) revert InvalidAddress();
        manufacturerWallet = _manufacturerWallet;
        partnerWallet = _partnerWallet;
        emit WalletsUpdated(_manufacturerWallet, _partnerWallet);
    }

    /**
     * @notice Update cut percentages
     */
    function setCuts(
        uint96 _manufacturerCutBP,
        uint96 _partnerCutBP,
        uint96 _defaultCreatorCutBP
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        if (_manufacturerCutBP + _partnerCutBP + _defaultCreatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP = _partnerCutBP;
        defaultCreatorCutBP = _defaultCreatorCutBP;
        emit CutsUpdated(_manufacturerCutBP, _partnerCutBP, _defaultCreatorCutBP);
    }

    /**
     * @notice Set the default creator wallet (used when no creator is registered for a token)
     * @param _defaultCreatorWallet The fallback creator wallet address
     */
    function setDefaultCreatorWallet(address _defaultCreatorWallet) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        defaultCreatorWallet = _defaultCreatorWallet;
        emit DefaultCreatorWalletUpdated(_defaultCreatorWallet);
    }

    /**
     * @notice Allows a registered creator to change their own receiving wallet
     * @param tokenId The token ID for which they are the creator
     * @param newWallet The new wallet address to receive royalties
     */
    function updateCreatorWallet(uint256 tokenId, address newWallet) external {
        CreatorInfo storage info = tokenCreators[tokenId];
        if (info.creator != msg.sender) revert NotCreatorOfToken();
        if (newWallet == address(0)) revert InvalidAddress();

        address oldWallet = info.creator;
        info.creator = newWallet;

        emit CreatorWalletUpdated(tokenId, oldWallet, newWallet);
    }

    /**
     * @notice Admin/Distributor can override creator registration
     * @param tokenId The token ID
     * @param creator The new creator address
     * @param creatorCutBP The creator's royalty cut in basis points
     */
    function overrideCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
            hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
            hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized to override"
        );

        if (creator == address(0)) revert InvalidAddress();
        if (manufacturerCutBP + partnerCutBP + creatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }

        tokenCreators[tokenId] = CreatorInfo({
            creator: creator,
            creatorCutBP: creatorCutBP
        });

        emit CreatorOverridden(tokenId, creator, creatorCutBP);
    }

    /*//////////////////////////////////////////////////////////////
                         DISTRIBUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Distribute ETH royalty for a specific token sale
     * @param tokenId The token that was sold
     * @param amount The royalty amount to distribute
     */
    function distributeETH(uint256 tokenId, uint256 amount) external nonReentrant {
        _distributeETH(tokenId, amount);
    }

    /**
     * @notice Distribute ERC20 royalty for a specific token sale
     * @param tokenId The token that was sold
     * @param token The ERC20 token address
     * @param amount The royalty amount to distribute
     */
    function distributeERC20(
        uint256 tokenId,
        address token,
        uint256 amount
    ) external nonReentrant {
        _distributeERC20(tokenId, token, amount);
    }

    /**
     * @notice Internal ETH distribution logic
     */
    function _distributeETH(uint256 tokenId, uint256 amount) internal {
        (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        ) = _calculateSplit(tokenId, amount);

        // Accumulate pending balances
        pendingETH[manufacturerWallet] += manufacturerAmount;
        if (partnerWallet != address(0) && partnerAmount > 0) {
            pendingETH[partnerWallet] += partnerAmount;
        } else {
            // If no partner, manufacturer gets their share too
            pendingETH[manufacturerWallet] += partnerAmount;
        }
        if (creator != address(0) && creatorAmount > 0) {
            pendingETH[creator] += creatorAmount;
        } else {
            // If no creator, manufacturer gets their share
            pendingETH[manufacturerWallet] += creatorAmount;
        }

        emit RoyaltyDistributed(tokenId, manufacturerAmount, partnerAmount, creatorAmount, creator);
    }

    /**
     * @notice Internal ERC20 distribution logic
     */
    function _distributeERC20(uint256 tokenId, address token, uint256 amount) internal {
        (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        ) = _calculateSplit(tokenId, amount);

        pendingERC20[token][manufacturerWallet] += manufacturerAmount;
        if (partnerWallet != address(0) && partnerAmount > 0) {
            pendingERC20[token][partnerWallet] += partnerAmount;
        } else {
            pendingERC20[token][manufacturerWallet] += partnerAmount;
        }
        if (creator != address(0) && creatorAmount > 0) {
            pendingERC20[token][creator] += creatorAmount;
        } else {
            pendingERC20[token][manufacturerWallet] += creatorAmount;
        }

        emit RoyaltyDistributed(tokenId, manufacturerAmount, partnerAmount, creatorAmount, creator);
    }

    /**
     * @notice Calculate the split for a given token and amount
     * @dev Creator receives their cut on ALL sales (no first sale distinction)
     */
    function _calculateSplit(uint256 tokenId, uint256 amount)
        internal
        view
        returns (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        )
    {
        CreatorInfo memory info = tokenCreators[tokenId];
        bool hasCreator = info.creator != address(0);

        // Determine creator cut and address
        // If no creator registered, fallback to defaultCreatorWallet with defaultCreatorCutBP
        if (hasCreator) {
            creator = info.creator;
        } else if (defaultCreatorWallet != address(0)) {
            creator = defaultCreatorWallet;
        } else {
            creator = address(0);
        }

        uint96 actualCreatorCutBP = hasCreator ? info.creatorCutBP : defaultCreatorCutBP;

        // Calculate amounts
        uint256 totalBP = manufacturerCutBP + partnerCutBP + actualCreatorCutBP;

        if (totalBP == 0) {
            // No splits configured, everything to manufacturer
            return (amount, 0, 0, address(0));
        }

        // Proportional distribution based on the ACTUAL cuts (not max)
        // The received amount is based on MAX_TOTAL_ROYALTY_BP from OpenSea
        // We distribute based on actual cuts, remainder goes to manufacturer

        manufacturerAmount = (amount * manufacturerCutBP) / MAX_TOTAL_ROYALTY_BP;
        partnerAmount = (amount * partnerCutBP) / MAX_TOTAL_ROYALTY_BP;
        creatorAmount = (amount * actualCreatorCutBP) / MAX_TOTAL_ROYALTY_BP;

        // Any remainder (from tokens with lower creator cut) goes to manufacturer
        uint256 distributed = manufacturerAmount + partnerAmount + creatorAmount;
        if (distributed < amount) {
            manufacturerAmount += (amount - distributed);
        }
    }

    /**
     * @notice Get the split breakdown for a token (view function for frontends)
     */
    function getSplit(uint256 tokenId, uint256 amount)
        external
        view
        returns (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator,
            uint96 creatorCutBP
        )
    {
        CreatorInfo memory info = tokenCreators[tokenId];
        bool hasCreator = info.creator != address(0);
        creatorCutBP = hasCreator ? info.creatorCutBP : defaultCreatorCutBP;

        (manufacturerAmount, partnerAmount, creatorAmount, creator) = _calculateSplit(tokenId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw accumulated ETH
     */
    function withdrawETH() external nonReentrant {
        uint256 amount = pendingETH[msg.sender];
        if (amount == 0) revert NoFundsToWithdraw();
        
        pendingETH[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Withdrawn(msg.sender, amount, address(0));
    }

    /**
     * @notice Withdraw accumulated ERC20 tokens
     */
    function withdrawERC20(address token) external nonReentrant {
        uint256 amount = pendingERC20[token][msg.sender];
        if (amount == 0) revert NoFundsToWithdraw();
        
        pendingERC20[token][msg.sender] = 0;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, token);
    }

    /**
     * @notice Admin function to distribute all pending ETH in contract
     *         Useful if royalties were sent without calling distribute()
     */
    function sweepETH(uint256 tokenId) external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            _distributeETH(tokenId, balance);
        }
    }

    /**
     * @notice Admin function to distribute all pending ERC20 in contract
     */
    function sweepERC20(uint256 tokenId, address token) external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            _distributeERC20(tokenId, token, balance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a token has creator info registered
     */
    function hasCreatorInfo(uint256 tokenId) external view returns (bool) {
        return tokenCreators[tokenId].creator != address(0);
    }

    /**
     * @notice Get creator info for a token
     */
    function getCreatorInfo(uint256 tokenId)
        external
        view
        returns (address creator, uint96 cutBP)
    {
        CreatorInfo memory info = tokenCreators[tokenId];
        return (info.creator, info.creatorCutBP);
    }

    /**
     * @notice Get total pending ETH for an address
     */
    function getPendingETH(address recipient) external view returns (uint256) {
        return pendingETH[recipient];
    }

    /**
     * @notice Get total pending ERC20 for an address
     */
    function getPendingERC20(address token, address recipient) external view returns (uint256) {
        return pendingERC20[token][recipient];
    }
}
