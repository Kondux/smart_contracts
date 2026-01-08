# Mainnet Upgrade Plan: Beacon + Factory + BatchMinter

**Date**: January 2026  
**Script**: `scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol`

---

## Overview

This deployment upgrades the existing beacon implementation and deploys a new factory with updated `deployCloneWithSplitter()` signature that properly sets the royalty splitter on clones.

### What This Fixes
- `royaltyInfo()` now correctly returns the splitter address (was returning clone address)
- New clones will have `royaltySplitter` storage set during initialization

---

## Current Mainnet Addresses (Pre-Upgrade)

| Contract | Address | Notes |
|----------|---------|-------|
| Old Factory | `0xa265a01205f304F2652277AaC924AB56D2e0Cf77` | Will be deprecated |
| Old Beacon | `0x21D1a52A17a1Df346Dd223Ef89D0e362Ee64b219` | Will be upgraded |
| Current Implementation | `0xd5E8Ac6284825D99dAE3d16Bef4537d4B665E1Be` | Will be replaced |
| Factory Admin | `0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2` | Has DEFAULT_ADMIN_ROLE |
| Authority | `0x6A005c11217863c4e300Ce009c5Ddc7e1672150A` | For BatchMinter vault |
| Old BatchMinter | `0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF` | Can be repointed |

---

## Deployment Steps

### Step 1: Deploy New Implementation
- Deploys `KonduxImplementation` with updated `initialize()` signature
- New signature accepts `royaltySplitter` parameter

### Step 2: Upgrade Beacon
- Calls `factory.upgradeImplementation(newImpl)` on old factory
- All existing clones automatically use new implementation
- Existing clones continue working (storage unchanged)

### Step 3: Deploy New Factory
- Deploys `KonduxBeaconFactory` with new implementation
- Configures roles:
  - `DEFAULT_ADMIN_ROLE` → deployer
  - `FEE_ADMIN_ROLE` → deployer (or `FEE_ADMIN` env var)
  - `CLONE_DEPLOYER_ROLE` → deployer (or `CLONE_DEPLOYER` env var)
- Sets `publicDeployment` → false (or `PUBLIC_DEPLOYMENT` env var)

### Step 4: Deploy Test Clone (Optional)
- Deploys clone with splitter via new factory
- Verifies `royaltyInfo()` returns splitter address
- Clone config:
  - Name: "DryRunTest" (or `TEST_NAME` env var)
  - Symbol: "DRT" (or `TEST_SYMBOL` env var)
  - Max Supply: 100 (or `TEST_MAX_SUPPLY` env var)
  - Royalty: 10% (5% manufacturer + 5% creator)

### Step 5: Deploy BatchMinter (Optional)
- Deploys `KonduxBatchMinter` pointing to test clone
- Grants `MINTER_ROLE` on clone to BatchMinter
- Grants `BATCH_MINTER_ROLE` to admin (or `BATCH_MINTER_SIGNER` env var)

---

## Access Control Matrix

### KonduxBeaconFactory (New)
| Role | Granted To | Purpose |
|------|------------|---------|
| DEFAULT_ADMIN_ROLE | deployer | Admin operations |
| FEE_ADMIN_ROLE | deployer | Manage deployment fees |
| CLONE_DEPLOYER_ROLE | deployer | Deploy new clones (if !publicDeployment) |

### KonduxImplementation (Clone)
| Role | Granted To | Purpose |
|------|------------|---------|
| DEFAULT_ADMIN_ROLE | initialAdmin, factory | Admin operations |
| MINTER_ROLE | initialAdmin, BatchMinter | Mint NFTs |
| DNA_MODIFIER_ROLE | initialAdmin | Modify token DNA |

### KonduxRoyaltySplitter
| Role | Granted To | Purpose |
|------|------------|---------|
| DEFAULT_ADMIN_ROLE | admin | Admin operations |
| ADMIN_ROLE | admin | Manage splitter |
| FEE_ADMIN_ROLE | admin | Manage fee splits |
| DISTRIBUTOR_ROLE | admin | Distribute royalties |
| COLLECTION_ROLE | clone | Set creator per token |

### KonduxBatchMinter
| Role | Granted To | Purpose |
|------|------------|---------|
| DEFAULT_ADMIN_ROLE | deployer | Admin operations |
| BATCH_MINTER_ROLE | signer | Sign batch mint requests |

---

## Environment Variables

### Required
```bash
DEPLOYER_PK=<private_key>        # Or PROD_DEPLOYER_PK
MAINNET_RPC_URL=<rpc_url>
```

### Optional
```bash
DRY_RUN=true                     # Default: true (fork simulation)
DEPLOY_TEST_CLONE=true           # Default: true
DEPLOY_BATCH_MINTER=true         # Default: true
PUBLIC_DEPLOYMENT=false          # Default: false
CLONE_DEPLOYER=<address>         # Default: deployer
FEE_ADMIN=<address>              # Default: deployer
BATCH_MINTER_SIGNER=<address>    # Default: deployer
TEST_NAME=<string>               # Default: "DryRunTest"
TEST_SYMBOL=<string>             # Default: "DRT"
TEST_MAX_SUPPLY=<uint>           # Default: 100
```

---

## Deployment Commands

### Dry Run (Mainnet Fork)
```bash
forge script scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol \
  --rpc-url $MAINNET_RPC_URL -vvv
```

### Live Deployment
```bash
DRY_RUN=false forge script scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol \
  --rpc-url $MAINNET_RPC_URL --broadcast -vvv
```

### Production Deployment (Custom Config)
```bash
DRY_RUN=false \
DEPLOY_TEST_CLONE=true \
DEPLOY_BATCH_MINTER=true \
TEST_NAME="Kondux Genesis" \
TEST_SYMBOL="KGEN" \
TEST_MAX_SUPPLY=10000 \
BATCH_MINTER_SIGNER=0x... \
forge script scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol \
  --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvv
```

---

## Post-Deployment Checklist

- [ ] Verify new implementation on Etherscan
- [ ] Verify new factory on Etherscan
- [ ] Verify test clone on Etherscan (if deployed)
- [ ] Verify splitter on Etherscan (if deployed)
- [ ] Verify BatchMinter on Etherscan (if deployed)
- [ ] Test `royaltyInfo()` returns splitter address
- [ ] Test BatchMinter can mint on clone
- [ ] Update frontend/backend with new factory address
- [ ] Update address-book.json with new addresses
- [ ] Deprecate old factory in documentation

---

## Verification Results (Dry Run)

Last dry run: **PASSED**

| Check | Result |
|-------|--------|
| Beacon upgraded | ✅ |
| New factory deployed | ✅ |
| Test clone deployed | ✅ |
| `royaltyInfo()` returns splitter | ✅ |
| Clone has COLLECTION_ROLE on splitter | ✅ |
| BatchMinter has MINTER_ROLE on clone | ✅ |
| BatchMinter targets correct clone | ✅ |
| BatchMinter not paused | ✅ |

---

## Repointing Existing BatchMinter

The existing BatchMinter at `0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF` can be pointed to a new clone:

```solidity
// 1. On BatchMinter (as DEFAULT_ADMIN)
KonduxBatchMinter(0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF).setKNFT(newCloneAddress);

// 2. On new clone (as admin) - grant MINTER_ROLE
KonduxImplementation(newClone).grantRole(MINTER_ROLE, 0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF);
```

---

## Rollback Plan

If issues arise:
1. Deploy previous implementation version
2. Call `factory.upgradeImplementation(oldImpl)` to rollback beacon
3. All clones revert to previous behavior
4. New factory can be abandoned (no state to migrate)
