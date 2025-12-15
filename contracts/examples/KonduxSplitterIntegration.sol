// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IKonduxRoyaltySplitter.sol";

/**
 * @title KonduxImplementation Integration Guide
 * @notice This shows the exact additions needed to KonduxImplementation.sol to support
 *         atomic royalty splitting during Seaport/marketplace settlements.
 *
 * THE KEY INSIGHT:
 * ================
 * Seaport doesn't send ETH through the NFT transfer. It sends ETH directly to
 * consideration recipients. So we need to:
 * 1. Tell the splitter which tokenId is being sold (in _update)
 * 2. Let the splitter's receive() handle the incoming royalty payment
 * 
 * This happens atomically in the same Seaport transaction:
 * - Seaport calls NFT.transferFrom() → our _update sets lastSoldTokenId
 * - Seaport sends ETH to splitter → splitter.receive() distributes immediately
 */

// ============================================================================
// 1. ADD THESE IMPORTS TO KonduxImplementation.sol
// ============================================================================

// import "./interfaces/IKonduxRoyaltySplitter.sol";

// ============================================================================
// 2. ADD THESE STATE VARIABLES (after partnerWallet, around line 105)
// ============================================================================

/*
    /// @notice The royalty splitter contract for atomic distribution
    address public royaltySplitter;
*/

// ============================================================================
// 3. ADD THIS EVENT (in the events section, around line 121)
// ============================================================================

/*
    event RoyaltySplitterUpdated(address indexed splitter);
*/

// ============================================================================
// 4. ADD THIS ADMIN FUNCTION (after setPartnerWallet, around line 240)
// ============================================================================

/*
    /**
     * @notice Sets the royalty splitter contract address
     * @param _splitter The address of the KonduxRoyaltySplitter contract
     */
/*
    function setRoyaltySplitter(address _splitter) external onlyAdmin {
        royaltySplitter = _splitter;
        // Also update ERC2981 royalty receiver to point to splitter
        if (_splitter != address(0)) {
            uint96 totalRoyalty = manufacturerCutBP + partnerCutBP + creatorCutBP;
            _setDefaultRoyalty(_splitter, totalRoyalty);
        }
        emit RoyaltySplitterUpdated(_splitter);
    }
*/

// ============================================================================
// 5. MODIFY THE _update FUNCTION (around line 516)
// ============================================================================

/*
    Replace the existing _update function with this version:
*/

abstract contract KonduxSplitterIntegrationExample {
    // Placeholder for inherited functions
    function _ownerOf(uint256) internal view virtual returns (address);
    function getTransferValidator() public view virtual returns (address);
    
    address public royaltySplitter;
    
    // Paste this updated _update function:
    
    /**
     * @notice Overrides the standard ERC721 update hook to insert transfer
     *         validator logic and royalty splitter notification.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        returns (address prevOwner)
    {
        address from = _ownerOf(tokenId);
        bool isMint = (from == address(0));
        bool isBurn = (to == address(0));

        // Pre‑validate transfer through external validator for normal transfers
        if (!isMint && !isBurn) {
            // Transfer validator check (existing code)
            address validator = getTransferValidator();
            if (validator != address(0)) {
                // ITransferValidator(validator).validateTransfer(msg.sender, from, to, tokenId);
            }
            
            // ═══════════════════════════════════════════════════════════════
            // NEW: Notify splitter of impending sale for atomic distribution
            // ═══════════════════════════════════════════════════════════════
            if (royaltySplitter != address(0)) {
                // This registers the sale so when Seaport sends ETH to the splitter
                // (as a consideration item), it knows which token was sold
                try IKonduxRoyaltySplitter(royaltySplitter).registerSale(tokenId) {} catch {}
            }
        }

        // Perform the actual update via parent hooks
        // prevOwner = super._update(to, tokenId, auth);

        // Clear EIP-4907 user info on transfer (existing code)
        // ...
    }
}

// ============================================================================
// 6. ADD MINTING WITH CREATOR REGISTRATION (for per-token creator royalties)
// ============================================================================

/*
    /**
     * @notice Mint with creator registration (for per-token royalty splits)
     * @param to Recipient of the NFT
     * @param dna Token DNA
     * @param creator The creator address for royalty splits
     * @param creatorCutBP The creator's cut in basis points
     */
/*
    function safeMintWithCreator(
        address to, 
        uint256 dna,
        address creator,
        uint96 creatorCutBP
    ) public onlyMinter returns (uint256) {
        uint256 tokenId = safeMint(to, dna);
        
        // Register creator in the splitter for this token
        if (royaltySplitter != address(0) && creator != address(0)) {
            IKonduxRoyaltySplitter(royaltySplitter).registerCreator(
                tokenId,
                creator,
                creatorCutBP
            );
        }
        
        return tokenId;
    }
*/

// ============================================================================
// HOW IT WORKS (SEAPORT FLOW)
// ============================================================================

/*
    When a buyer purchases via OpenSea/Seaport:
    
    1. Buyer calls Seaport.fulfillOrder() with payment
    
    2. Seaport atomically executes:
       a) Transfers NFT: calls collection.transferFrom(seller, buyer, tokenId)
          → Our _update() is triggered
          → We call splitter.setLastSoldToken(tokenId)
          
       b) Distributes payments to consideration recipients:
          → Seller receives (price - fees - royalty)
          → OpenSea receives 2.5%
          → Splitter receives 10% (the "creator fee")
          
       c) When splitter receives ETH:
          → splitter.receive() is triggered
          → It sees lastSoldTokenId is set
          → It immediately distributes to manufacturer/partner/creator
          → Resets lastSoldTokenId to 0
    
    All in ONE transaction! Creator gets paid instantly.

    TIMING WITHIN TRANSACTION:
    ──────────────────────────
    Step 1: NFT.transferFrom() called by Seaport
            └─> _update() executes
                └─> splitter.setLastSoldToken(tokenId) ✓
    
    Step 2: Seaport sends ETH to splitter address
            └─> splitter.receive() executes  
                └─> Checks lastSoldTokenId (set in Step 1)
                └─> Distributes immediately to m/p/c
                └─> Resets lastSoldTokenId to 0
    
    Transaction completes. Everyone is paid.
*/

// ============================================================================
// DEPLOYMENT CHECKLIST
// ============================================================================

/*
    1. Deploy KonduxRoyaltySplitter:
       splitter = new KonduxRoyaltySplitter(
           collection,          // NFT contract address
           konduxTreasury,      // manufacturer wallet (4%)
           partnerWallet,       // partner wallet (3%)
           400,                 // manufacturer cut BP
           300,                 // partner cut BP
           300,                 // default creator cut BP (max 3%)
           admin                // admin address
       );

    2. Configure the NFT collection:
       collection.setRoyaltySplitter(address(splitter));
       
       // This also updates ERC2981 to return splitter as receiver

    3. Enable push mode for immediate distribution:
       splitter.setPushMode(true);

    4. Grant COLLECTION_ROLE to NFT contract:
       splitter.grantRole(COLLECTION_ROLE, address(collection));

    5. Configure OpenSea:
       Set creator_fees = 10% pointing to splitter address
       (This should be auto-detected from ERC2981)

    6. For each mint with creator info:
       collection.safeMintWithCreator(to, dna, creator, creatorCutBP);
       // OR
       splitter.registerCreator(tokenId, creator, creatorCutBP);
*/
