# Sepolia Deployment Plan: Fresh Beacon + Factory + BatchMinter

**Date**: January 2026  
**Script**: `scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol`

---

## Overview

This deployment creates a **fresh beacon proxy system** on Sepolia testnet. Unlike mainnet (which has an existing beacon to upgrade), Sepolia requires deploying all components from scratch.

### What This Deploys
- New `KonduxImplementation` (beacon logic contract)
- New `UpgradeableBeacon` pointing to the implementation
- New `KonduxBeaconFactory` for deploying clones
- Test clone + splitter (optional)
- BatchMinter for the test clone (optional)

---

## Current Sepolia State

### Existing Contracts (Legacy - ERC1967 Proxy)

| Contract | Address | Notes |
|----------|---------|-------|
| Authority | `0x685a13093ca561f531c93185b942a3f33385e14e` | For BatchMinter vault |
| KNDX Token | `0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc` | Test token |
| Founders Pass | `0x434fD7FEEc752c4BfA4a59d0272c503ffD313499` | Legacy NFT |
| KonduxImplementation (ERC1967) | `0x99e35928d46683eda983c5d84d39004a5ff01123` | Old proxy pattern |

### New Contracts (To Be Deployed)

| Contract | Address | Notes |
|----------|---------|-------|
| Implementation | TBD | New logic contract |
| Beacon | TBD | New UpgradeableBeacon |
| Factory | TBD | New KonduxBeaconFactory |
| Test Clone | TBD | Optional test collection |
| Test Splitter | TBD | Optional royalty splitter |
| BatchMinter | TBD | Optional batch minter |

---

## Deployment Steps

### Step 1: Deploy New Implementation
- Deploys `KonduxImplementation` with updated `initialize()` signature
- This becomes the beacon's logic contract

### Step 2: Deploy New Beacon
- Deploys `UpgradeableBeacon` pointing to the implementation
- Owner set to deployer (or factory, depending on config)

### Step 3: Deploy New Factory
- Deploys `KonduxBeaconFactory` with the beacon
- Configures roles:
  - `DEFAULT_ADMIN_ROLE` → deployer
  - `FEE_ADMIN_ROLE` → deployer (or `FEE_ADMIN` env var)
  - `CLONE_DEPLOYER_ROLE` → deployer (or `CLONE_DEPLOYER` env var)
- Sets `publicDeployment` → false (or `PUBLIC_DEPLOYMENT` env var)

### Step 4: Deploy Test Clone (Optional)
- Deploys clone with splitter via new factory
- Verifies `royaltyInfo()` returns splitter address
- Clone config:
  - Name: "SepoliaTest" (or `TEST_NAME` env var)
  - Symbol: "SEPT" (or `TEST_SYMBOL` env var)
  - Max Supply: 1000 (or `TEST_MAX_SUPPLY` env var)
  - Royalty: 10% (5% manufacturer + 5% creator)

### Step 5: Deploy BatchMinter (Optional)
- Deploys `KonduxBatchMinter` pointing to test clone
- Grants `MINTER_ROLE` on clone to BatchMinter
- Grants `BATCH_MINTER_ROLE` to admin (or `BATCH_MINTER_SIGNER` env var)

---

## Access Control Matrix

### KonduxBeaconFactory
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
DEPLOYER_PK=<private_key>        # Sepolia deployer private key
SEPOLIA_RPC_URL=<rpc_url>        # Sepolia RPC endpoint
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
TEST_NAME=<string>               # Default: "SepoliaTest"
TEST_SYMBOL=<string>             # Default: "SEPT"
TEST_MAX_SUPPLY=<uint>           # Default: 1000
```

### Sepolia-Specific Constants (Hardcoded)
```solidity
AUTHORITY = 0x685a13093ca561f531c93185b942a3f33385e14e  // For BatchMinter
```

---

## Deployment Commands

### Dry Run (Sepolia Fork)
```bash
forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol \
  --rpc-url $SEPOLIA_RPC_URL -vvv
```

### Live Deployment
```bash
DRY_RUN=false forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol \
  --rpc-url $SEPOLIA_RPC_URL --broadcast -vvv
```

### Production Deployment (Custom Config)
```bash
DRY_RUN=false \
DEPLOY_TEST_CLONE=true \
DEPLOY_BATCH_MINTER=true \
TEST_NAME="Kondux Sepolia" \
TEST_SYMBOL="KSEP" \
TEST_MAX_SUPPLY=10000 \
BATCH_MINTER_SIGNER=0x... \
forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol \
  --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvv
```

### Windows + WSL Commands
```powershell
# Dry run
wsl -e bash -c "cd /mnt/d/git/smart_contracts && ~/.foundry/bin/forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol --rpc-url \$SEPOLIA_RPC_URL -vvv"

# Live deployment
wsl -e bash -c "cd /mnt/d/git/smart_contracts && DRY_RUN=false ~/.foundry/bin/forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol --rpc-url \$SEPOLIA_RPC_URL --broadcast -vvv"
```

---

## Post-Deployment Checklist

- [ ] Verify implementation on Etherscan Sepolia
- [ ] Verify beacon on Etherscan Sepolia
- [ ] Verify factory on Etherscan Sepolia
- [ ] Verify test clone on Etherscan Sepolia (if deployed)
- [ ] Verify splitter on Etherscan Sepolia (if deployed)
- [ ] Verify BatchMinter on Etherscan Sepolia (if deployed)
- [ ] Test `royaltyInfo()` returns splitter address
- [ ] Test BatchMinter can mint on clone
- [ ] Update historical-addresses.json with new addresses
- [ ] Update address-book.json with Sepolia entries

---

## Differences from Mainnet

| Aspect | Mainnet | Sepolia |
|--------|---------|---------|
| Existing beacon | Yes - upgrade | No - fresh deploy |
| Script | `UpgradeBeaconAndDeployFactory.s.sol` | `DeployBeaconFactoryFresh.s.sol` |
| Authority address | `0x6A005c11217863c4e300Ce009c5Ddc7e1672150A` | `0x685a13093ca561f531c93185b942a3f33385e14e` |
| Old factory | Deprecated after upgrade | N/A |
| Old beacon | Upgraded in place | N/A |

---

## Verification Results (Dry Run)

Last dry run: **January 8, 2026 - PASSED ✅**

| Check | Result |
|-------|--------|
| Implementation deployed | ✅ 0xfA3Bcec395737D69058e2b07797F7fAe93c713B4 |
| Beacon deployed | ✅ 0x32A4Acd628EAa026E50Cf63918812D9de4DBbc58 |
| Factory deployed | ✅ 0x2DF3272AC9cE874C8e9Ac0440624b9bAd68fC942 |
| Test clone deployed | ✅ 0x7695906097a7f23c759D397cDE4be63e85CD645B |
| Test splitter deployed | ✅ 0x64fD1425bbC7BC3DDB7abF7cEf3AD16C4FB9D399 |
| `royaltyInfo()` returns splitter | ✅ SUCCESS |
| Clone has COLLECTION_ROLE on splitter | ✅ true |
| BatchMinter deployed | ✅ 0xE3084bBc0C5456AACC72E59cA157cE04824C2bA5 |
| BatchMinter has MINTER_ROLE on clone | ✅ true |
| BatchMinter targets correct clone | ✅ SUCCESS |
| BatchMinter not paused | ✅ false |

**Note**: Addresses above are from fork simulation. Actual deployed addresses will differ.

---

## Testing on Sepolia

After deployment, test the full flow:

1. **Mint via BatchMinter**
   ```solidity
   // Create voucher off-chain, then:
   batchMinter.mintBatchWithSignature(voucher, signature);
   ```

2. **List on OpenSea Testnets**
   - Visit: https://testnets.opensea.io/
   - Import collection using clone address

3. **Verify Royalties**
   - Sell NFT on OpenSea testnets
   - Verify royalties go to splitter
   - Verify splitter distributes correctly

---

## Rollback Plan

Since this is a fresh deployment, rollback is simple:
1. Stop using the deployed contracts
2. Deploy again with corrected configuration
3. No state migration needed (testnet)
