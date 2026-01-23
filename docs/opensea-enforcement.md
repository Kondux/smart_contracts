# OpenSea Creator Earnings Enforcement (ERC721-C)

**Date:** 2026-01-20  
**Status:** ACTIVE  
**Implementation:** Limit Break V5 + Seaport 1.6 Whitelist

## Overview

Kondux NFT collections use the **Limit Break Creator Token Standard (ERC721-C)** to enforce royalties on OpenSea and other marketplaces. This setup requires specific on-chain configuration and manual activation in OpenSea Studio.

## Architecture

*   **Standard:** ERC721-C (Limit Break V5)
*   **Transfer Validator:** `0x721C008fdff27BF06E7E123956E2Fe03B63342e3` (Limit Break V5)
*   **Factory:** `0x539F8627Bd33E7c0D8320b1e7d7477d436Ffd12c` (V3 Upgradeable Proxy)
*   **Security Level:** **4** (Operator Whitelist, OTC Disabled)
*   **Whitelisted Operators:**
    *   **Seaport 1.6:** `0x0000000000000068F116a894984e2DB1123eB395`
    *   **OpenSea Conduit:** `0x1E0049783F008A0085193E00003D00cd54003c71`

## Requirements for Enforcement

For OpenSea to show the **"Turn on enforced earnings"** toggle, the contract must meet **ALL** of these criteria:

1.  **Interface Support:** Implement `ICreatorToken` (ID `0xad0d7f6c`) or `ICreatorTokenLegacy` (ID `0xa07d229a`).
2.  **Ownership:** Expose an `owner()` function that returns the admin address (required for OpenSea Studio verification).
3.  **Validator:** `getTransferValidator()` must return a valid Limit Break validator.
4.  **Earnings Config:** Payout addresses must be set in OpenSea Studio first.

## Deployment & Setup

### 1. Automatic Setup (Recommended)
Use the V3 Factory or scripts that use it. The factory automatically:
*   Sets Security Level 4.
*   Creates a whitelist.
*   Adds Seaport 1.6 and OpenSea Conduit.

**Script:** `scripts/solidity/deploy/DeployCollectionWithSplitter.s.sol`

### 2. Manual Setup (If needed)
If deploying standalone or fixing an old collection, run these functions as admin:

```solidity
// 1. Set Transfer Validator (if not already set)
collection.setTransferValidator(0x721C008fdff27BF06E7E123956E2Fe03B63342e3);

// 2. Configure Security Policy
collection.setToDefaultSecurityPolicy();

// 3. Whitelist OpenSea Conduit
address[] memory conduits = new address[](1);
conduit[0] = 0x1E0049783F008A0085193E00003D00cd54003c71;
collection.addAccountsToWhitelist(conduit);
```

## OpenSea Studio Activation (MANDATORY)

Enforcement is **NOT automatic** on OpenSea's UI. You must perform these steps:

1.  Go to **OpenSea Studio** (studio.opensea.io) -> Your Collection.
2.  Go to **Settings -> Creator Earnings**.
3.  **Add Payout Address:** Set your earnings % and wallet.
4.  **Refresh Eligibility:** Click "Refresh eligibility" if the enforcement toggle is missing.
5.  **Turn On Enforcement:** Click **"Turn on enforced earnings"** and sign the transaction.
6.  **Verify:** Wait 15-30 minutes and check the collection page.

## Troubleshooting

**"Enforce Creator Earnings" toggle missing?**
*   Ensure `owner()` function exists and returns your wallet address.
*   Ensure at least one NFT has been minted.
*   Click "Refresh Metadata" on the collection page.
*   Check on-chain state:
    *   `getCollectionSecurityPolicy(address)` on the validator should return Level 4.
    *   `getTransferValidator()` on the collection should be V5.

**Legacy Collections (deployed before V3 factory)**
*   Legacy clones (`0xaa03...`) have been upgraded to the V5 implementation.
*   They expose `owner()` correctly.
*   If enforcement drops, re-run the **Manual Setup** steps above.
