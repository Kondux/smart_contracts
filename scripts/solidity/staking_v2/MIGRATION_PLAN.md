# Staking V1 → V2 Migration Plan

**Date:** 2026-02-02  
**Status:** Ready for Execution  
**Networks:** Mainnet (1), Sepolia (11155111), Local Anvil Fork (31337)  

### Contract Addresses by Network

**Ethereum Mainnet (Chain ID: 1)**

| Contract | Address |
|----------|---------|
| Staking V1 | `0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC` |
| Staking V2 | _TBD — deployed in Phase 1_ |
| KONDUX Token | `0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1` |
| Helix | `0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4` |
| Treasury | `0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E` |
| Authority | `0x6A005c11217863c4e300Ce009c5Ddc7e1672150A` |
| Founders Pass | `0x0fD5576c2842bD62dd00C5256491D11CcAD84306` |
| kNFT | `0xeA6aB2871d5B3bbe6Ded740C812D85700Bae33c0` |

**Ethereum Sepolia (Chain ID: 11155111)**

| Contract | Address |
|----------|---------|
| KONDUX Token | `0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc` |
| Helix | `0xb94F89750d9889656a6D081A0F06cBd3FA3Ad04B` |
| Authority | `0x685a13093cA561F531c93185B942a3f33385e14E` |
| Treasury | `0xD5A6Af8F9C20CAF7872611D6773152AA50180F83` |
| Founders Pass | `0x434Fd7feeC752C4Bfa4A59D0272c503FFd313499` |
| kNFT | `0x5C7eD88DBbD99F513235A1911d41A5C57E2FFB78` |

**Local Anvil Fork (Chain ID: 31337)**
- Uses mainnet addresses by default when forked (`anvil --fork-url $MAINNET_RPC_URL`)
- Auto-detects fork vs fresh Anvil by checking if mainnet Authority contract exists
- All addresses overridable via env vars

---

## Multi-Network Support

All scripts in `scripts/solidity/staking_v2/` detect the network via `block.chainid` and select addresses automatically. Every hardcoded address can be overridden via environment variables.

### Environment Variable Overrides

| Variable | Description | Used By |
|----------|-------------|---------|
| `STAKING_V1_ADDRESS` | Override V1 staking address | Import, Shutdown |
| `STAKING_V2_ADDRESS` | V2 address (always required for Import/Shutdown) | Import, Shutdown |
| `KONDUX_TOKEN_ADDRESS` | Override KONDUX token address | All scripts |
| `HELIX_ADDRESS` | Override Helix token address | Deploy, Shutdown |
| `TREASURY_ADDRESS` | Override Treasury address | Deploy |
| `AUTHORITY_ADDRESS` | Override Authority address | Deploy, Shutdown |
| `FOUNDERS_ADDRESS` | Override Founders Pass address | Deploy |
| `KNFT_ADDRESS` | Override kNFT address | Deploy |
| `PROD_DEPLOYER_PK` | Deployer private key (mainnet / local) | All scripts |
| `DEPLOYER_PK` | Deployer private key (Sepolia) | All scripts |
| `STAKING_IMPORT_LIMIT` | Import first N deposits only (0 = all) | Import |
| `STAKING_IMPORT_BATCH` | Deposits per import batch (default: 25) | Import |
| `FORCE_IMPORT` | Continue if V2 already has deposits | Import |
| `FORCE_SHUTDOWN` | Skip deposit total comparison check | Shutdown |
| `SKIP_TREASURY_CHECK` | Skip Treasury allowance check | Shutdown |
| `DEPLOY_DEPENDENCIES` | Force fresh deploy on local (skip fork detection) | Deploy |

### Network-Specific Commands

**Local Anvil Fork (recommended for rehearsal):**

```bash
# Start Anvil with mainnet fork
anvil --fork-url $MAINNET_RPC_URL

# Phase 1: Deploy V2 (uses forked mainnet state)
forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol \
    --rpc-url http://127.0.0.1:8545 --broadcast -vvv

# Phase 2: Import deposits from forked V1
STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol \
    --rpc-url http://127.0.0.1:8545 --broadcast -vvv

# Phase 3: Shutdown V1, activate V2
STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol \
    --rpc-url http://127.0.0.1:8545 --broadcast -vvv
```

**Sepolia:**

```bash
# Phase 1: Deploy V2
forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol \
    --rpc-url sepolia --broadcast --verify -vvv

# Phase 2: Import (requires STAKING_V1_ADDRESS on Sepolia)
STAKING_V1_ADDRESS=<SEPOLIA_V1> STAKING_V2_ADDRESS=<V2_ADDR> \
    forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol \
    --rpc-url sepolia --broadcast -vvv

# Phase 3: Shutdown
STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol \
    --rpc-url sepolia --broadcast -vvv
```

**Mainnet:**

```bash
# Phase 1: Deploy V2
forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol \
    --rpc-url mainnet --broadcast --verify -vvv

# Phase 2: Import deposits
STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol \
    --rpc-url mainnet --broadcast -vvv

# Phase 3: Shutdown V1, activate V2
STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol \
    --rpc-url mainnet --broadcast -vvv
```

> All commands above assume WSL. Prefix with `wsl -e bash -c "cd /mnt/d/git/smart_contracts && ~/.foundry/bin/<command>"` on Windows.

---

## Overview

StakingV2 extends StakingV1 with per-deposit APR snapshots and deposit import functionality. The migration is a **deploy-new-and-import** approach (not an upgrade) because V1 is not behind a proxy. V2 inherits all V1 storage layout and adds two new mappings.

**What V2 preserves from V1:**
- All deposit data (staker, amounts, timelocks, timestamps, unclaimed rewards)
- All per-token configuration (APR, ratios, fees, boosts)
- All global configuration (timelock durations/boosts, DNA version allowlist)
- Helix minting/burning ratios and mechanics
- Treasury integration (reserve depositor/spender)
- NFT boost system (Founders + kNFT DNA)
- All accounting aggregates (totalStaked, totalRewarded, userTotalStaked, userTotalRewarded)
- Deposit ID continuity (nextDepositId counter preserved)

**What V2 adds:**
- Per-deposit APR snapshots (deposits keep the APR they were created with)
- Restaking blocked when APR changes (prevents gaming APR adjustments)
- `getDepositAprSnapshot()` view function

---

## Script Inventory

All scripts are in `scripts/solidity/staking_v2/`:

| Script | Purpose | Phase |
|--------|---------|-------|
| `DeployStakingV2.s.sol` | Deploy V2 contract, configure Helix roles + Treasury | Phase 1 |
| `ImportV1Deposits.s.sol` | Read V1 state, batch-import deposits into V2 | Phase 2 |
| `ShutdownStakingV1.s.sol` | Deauthorize V1, revoke roles, grant roles to V2 | Phase 3 |
| `DeployStakingV2SepoliaImport.s.sol` | Sepolia combined deploy+import (testnet only) | Pre-Phase |
| `deploy_staking_v2_sepolia.py` | Python CLI for Sepolia deployment | Pre-Phase |

---

## Pre-Phase: Local Fork + Testnet Rehearsal

> **Goal:** Full end-to-end dry run on local Anvil fork first, then Sepolia, before touching mainnet.

### Step A: Run Forge Tests

```bash
# All V2-related tests (unit, migration, E2E, shutdown)
forge test --match-contract "StakingV2|StakingV1Shutdown" -vvv
```

### Step B: Local Anvil Fork Rehearsal

Full migration rehearsal using forked mainnet state — zero cost, instant feedback:

```bash
# Terminal 1: Start Anvil with mainnet fork
anvil --fork-url $MAINNET_RPC_URL

# Terminal 2: Execute all 3 phases in sequence
forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol \
    --rpc-url http://127.0.0.1:8545 --broadcast -vvv

# Record V2 address from output, then:
STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol \
    --rpc-url http://127.0.0.1:8545 --broadcast -vvv

STAKING_V2_ADDRESS=<V2_ADDR> forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol \
    --rpc-url http://127.0.0.1:8545 --broadcast -vvv
```

### Step C: Sepolia Testnet (optional, for frontend integration testing)

Deploy on Sepolia using the combined deploy+import script:

```bash
python scripts/solidity/staking_v2/deploy_staking_v2_sepolia.py
```

Or use the phased scripts individually (requires `STAKING_V1_ADDRESS` since Sepolia has a different V1).

### Pre-Phase Checklist

- [ ] All Forge test suites pass (StakingV2, StakingV2Migration, StakingV2MigrationE2E, StakingV1Shutdown)
- [ ] Local Anvil fork: Phase 1 (deploy) succeeds
- [ ] Local Anvil fork: Phase 2 (import) succeeds, deposit counts match
- [ ] Local Anvil fork: Phase 3 (shutdown) succeeds, V1 operations revert
- [ ] Local Anvil fork: V2 deposit, withdraw, claimRewards, stakeRewards all work post-shutdown
- [ ] Sepolia V2 deployed and deposits imported (if doing frontend testing)
- [ ] Manual verification on Sepolia: all V2 operations work

---

## Phase 1: Deploy Staking V2 (Mainnet)

> **Goal:** Deploy V2 contract and configure integrations. V1 remains fully operational.  
> **Risk Level:** LOW — V1 is unaffected.  
> **Reversibility:** Full — V2 can be abandoned if issues found.

### Prerequisites

- [ ] `PROD_DEPLOYER_PK` set in environment (governor wallet)
- [ ] `MAINNET_RPC_URL` set (Alchemy/Infura)
- [ ] `ETHERSCAN_API_KEY` set (for verification)
- [ ] Governor wallet has sufficient ETH for gas (~0.1 ETH conservative)

### Steps

1. **Dry-run deployment (no broadcast):**
   ```bash
   # Mainnet
   forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol --rpc-url mainnet -vvv
   # Sepolia
   forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol --rpc-url sepolia -vvv
   # Local fork
   forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol --rpc-url http://127.0.0.1:8545 -vvv
   ```

2. **Live deployment:**
   ```bash
   # Mainnet (with Etherscan verification)
   forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol --rpc-url mainnet --broadcast --verify -vvv
   # Sepolia
   forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol --rpc-url sepolia --broadcast --verify -vvv
   # Local fork
   forge script scripts/solidity/staking_v2/DeployStakingV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv
   ```

3. **Record the deployed V2 address** from forge output. Export it:
   ```bash
   export STAKING_V2_ADDRESS=<deployed_address>
   ```

4. **Verify on Etherscan** (mainnet/sepolia only):
   - Contract source verified
   - Constructor arguments match expected values
   - Owner/authority is the correct address

### What This Does

- Deploys `StakingV2` with constructor args: `(authority, konduxToken, treasury, foundersPass, knft, helix)`
- Grants `MINTER_ROLE` on Helix to V2 (needed for deposit/compound)
- Grants `BURNER_ROLE` on Helix to V2 (needed for withdrawal)
- Adds V2 to Helix `allowedContracts` allowlist
- Registers V2 as `RESERVEDEPOSITOR` and `RESERVESPENDER` on Treasury
- **Does NOT** set V2 as `stakingContract` on Treasury (deferred to Phase 3 to avoid disrupting V1)
- **Does NOT** call `erc20ApprovalSetup` for V2 (deferred to Phase 3, requires `stakingContract` to be set first)

### Phase 1 Verification Checklist

- [ ] V2 contract deployed and verified on Etherscan
- [ ] V2 address recorded: `___________________________`
- [ ] V2 has `MINTER_ROLE` on Helix: `cast call <helix> "hasRole(bytes32,address)" <MINTER_HASH> <V2>`
- [ ] V2 has `BURNER_ROLE` on Helix: `cast call <helix> "hasRole(bytes32,address)" <BURNER_HASH> <V2>`
- [ ] V2 in Helix allowlist: `cast call <helix> "allowedContracts(address)" <V2>`
- [ ] V2 is `RESERVEDEPOSITOR` on Treasury
- [ ] V2 is `RESERVESPENDER` on Treasury
- [ ] Treasury `stakingContract()` still points to V1 (NOT changed yet)
- [ ] V1 still fully operational (test a small deposit/claim on V1)
- [ ] V2 has NO authorized tokens yet (prevents premature deposits)

---

## Phase 2: Import V1 Deposits into V2

> **Goal:** Read all V1 deposit state and replicate it into V2 with APR snapshots.  
> **Risk Level:** MEDIUM — Data fidelity is critical.  
> **Reversibility:** V2 can be redeployed if import is wrong. V1 unaffected.

### Prerequisites

- [ ] Phase 1 complete — V2 deployed and address known
- [ ] `STAKING_V2_ADDRESS` env var set to deployed V2 address
- [ ] V1 is still operational (we read from it)

### Steps

1. **Dry-run import (no broadcast) — verify deposit count:**
   ```bash
   # Mainnet
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol --rpc-url mainnet -vvv
   # Sepolia (requires STAKING_V1_ADDRESS)
   STAKING_V1_ADDRESS=<SEPOLIA_V1> STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol --rpc-url sepolia -vvv
   # Local fork (auto-detects mainnet V1 from forked state)
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol --rpc-url http://127.0.0.1:8545 -vvv
   ```
   Review console output:
   - Total deposits scanned
   - Active deposits to import
   - Skipped inactive count
   - Total stake amount
   - Preflight checks pass (dependency addresses match)

2. **Partial import test (first 5 deposits):**
   ```bash
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS STAKING_IMPORT_LIMIT=5 \
       forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol --rpc-url <network> --broadcast -vvv
   ```
   Verify those 5 deposits on-chain before proceeding.

3. **Full import:**
   ```bash
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ImportV1Deposits.s.sol --rpc-url <network> --broadcast -vvv
   ```
   Replace `<network>` with `mainnet`, `sepolia`, or `http://127.0.0.1:8545`.

### What This Does

- Reads V1 `_depositIds` counter via `vm.load` (storage slot 1)
- Iterates all deposit IDs 0..nextDepositId, collects active deposits
- Reads V1 global config (timelock durations, boosts, DNA versions)
- Reads V1 per-token config (APR, ratios, fees, boosts — 12+ params)
- Synchronizes global config onto V2
- Synchronizes per-token config onto V2
- Batch-imports deposits (default batch size 25) with APR snapshots
- Sets V2 `nextDepositId` to match V1 (deposit ID continuity)
- Runs post-import verification (spot-checks, aggregate totals, nextDepositId)

### Phase 2 Verification Checklist

- [ ] Import script dry-run shows correct deposit count
- [ ] V2 `nextDepositId` == V1 `nextDepositId`: `cast call <V2> "getNextDepositId()"`
- [ ] Spot-check 5 random deposits match V1 field-by-field:
  ```bash
  cast call <V1> "userDeposits(uint256)" <ID>
  cast call <V2> "userDeposits(uint256)" <ID>
  ```
- [ ] Each imported deposit has correct APR snapshot:
  ```bash
  cast call <V2> "getDepositAprSnapshot(uint256)" <ID>
  ```
- [ ] V2 `totalStaked(kondux)` >= V1 `totalStaked(kondux)`
- [ ] V2 `totalRewarded(kondux)` matches expected
- [ ] V2 per-token config matches V1:
  - [ ] `aprERC20(kondux)` matches
  - [ ] `ratioERC20(kondux)` matches
  - [ ] `withdrawalFeeERC20(kondux)` matches
  - [ ] `minStakeERC20(kondux)` matches
  - [ ] `compoundFreqERC20(kondux)` matches
  - [ ] `foundersRewardBoostERC20(kondux)` matches
  - [ ] `kNFTRewardBoostERC20(kondux)` matches
  - [ ] `decimalsERC20(kondux)` matches
  - [ ] `divisorERC20(kondux)` matches
- [ ] V2 global config matches V1:
  - [ ] `timelockDurations(0..3)` match
  - [ ] `timelockCategoryBoost(0..3)` match
  - [ ] `allowedDnaVersions(1)` matches
- [ ] V1 still fully operational (V2 import does NOT affect V1)
- [ ] V2 `authorizedERC20(kondux)` is true (token authorized for staking)

### Critical: Timing Window

Between Phase 2 (import) and Phase 3 (shutdown), users can still interact with V1. Any deposits/withdrawals on V1 **after** the import snapshot will be lost. To minimize this window:

1. Import during low-activity hours (UTC 4-8 AM)
2. Announce maintenance window beforehand
3. Execute Phase 3 immediately after Phase 2 verification
4. The `totalStaked` check in ShutdownStakingV1 will catch significant drift (V2 must >= V1)

---

## Phase 3: Shutdown V1, Activate V2

> **Goal:** Break V1 mechanics and make V2 the sole active staking contract.  
> **Risk Level:** HIGH — Irreversible for V1. V2 must be fully validated first.  
> **Reversibility:** V1 roles can be re-granted by governor if emergency. V2 token auth can be revoked.

### Prerequisites

- [ ] Phase 2 complete — all deposits imported and verified
- [ ] Update `ShutdownStakingV1.s.sol` mainnet config: set `stakingV2` to deployed address
- [ ] Communication sent to users about migration window

### Steps

1. **Set V2 address** (if not already exported):
   ```bash
   export STAKING_V2_ADDRESS=<deployed_V2_address>
   ```

2. **Dry-run shutdown:**
   ```bash
   # Mainnet
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol --rpc-url mainnet -vvv
   # Sepolia (requires STAKING_V1_ADDRESS)
   STAKING_V1_ADDRESS=<SEPOLIA_V1> STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol --rpc-url sepolia -vvv
   # Local fork
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol --rpc-url http://127.0.0.1:8545 -vvv
   ```
   Verify preflight checks pass:
   - Role hashes match expected values
   - V2 totalStaked >= V1 totalStaked
   - Treasury allowance OK
   - V2 in Helix allowlist

3. **Execute shutdown:**
   ```bash
   STAKING_V2_ADDRESS=$STAKING_V2_ADDRESS \
       forge script scripts/solidity/staking_v2/ShutdownStakingV1.s.sol --rpc-url <network> --broadcast -vvv
   ```
   Replace `<network>` with `mainnet`, `sepolia`, or `http://127.0.0.1:8545`.

### What This Does

**Phase 3A — Kill V1:**
- `setAuthorizedERC20(KONDUX, false)` on V1 → blocks new deposits
- Revoke `MINTER_ROLE` from V1 on Helix → blocks compound (stakeRewards) since Helix mint fails
- Revoke `BURNER_ROLE` from V1 on Helix → blocks withdrawals since Helix burn fails
- Revoke `RESERVESPENDER` from V1 on Treasury → blocks `claimRewards()` reward payouts

**Phase 3B — Enable V2 (ordering protection: verifies V1 is dead first):**
- Verify V1 has no MINTER_ROLE and no BURNER_ROLE (ordering protection)
- Grant `MINTER_ROLE` to V2 on Helix (if not already granted in Phase 1)
- Grant `BURNER_ROLE` to V2 on Helix (if not already granted in Phase 1)
- Set V2 as `stakingContract` on Treasury (deferred from Phase 1)
- Call `erc20ApprovalSetup` to grant V2 unlimited ERC20 approval from Treasury

**Phase 3C — Post-shutdown verification (read-only):**
- V1 has no Helix roles
- V2 has both Helix roles
- V1 KONDUX token unauthorized
- V2 KONDUX token authorized
- V1 is not `RESERVESPENDER` on Treasury
- Treasury `stakingContract()` points to V2

### How V1 Is "Broken"

V1 has no `Pausable` contract, so there's no pause switch. Instead, the shutdown achieves the same effect by breaking the operational dependencies:

| V1 Operation | Why It Fails After Shutdown |
|---|---|
| `deposit()` | `authorizedERC20[KONDUX] == false` → reverts |
| `withdraw()` | Helix `burn()` fails (V1 lost `BURNER_ROLE`) → reverts |
| `earlyUnstake()` | Same as withdraw — Helix burn fails |
| `stakeRewards()` | Helix `mint()` fails (V1 lost `MINTER_ROLE`) → reverts |
| `claimRewards()` | V1's `RESERVESPENDER` permission revoked on Treasury → `transferFrom(vault, ...)` fails |

### Phase 3 Verification Checklist

- [ ] V1 `authorizedERC20(KONDUX)` is `false`
- [ ] V1 has NO `MINTER_ROLE` on Helix
- [ ] V1 has NO `BURNER_ROLE` on Helix
- [ ] V2 has `MINTER_ROLE` on Helix
- [ ] V2 has `BURNER_ROLE` on Helix
- [ ] V1 is NOT `RESERVESPENDER` on Treasury
- [ ] Treasury `stakingContract()` returns V2 address
- [ ] V2 has ERC20 approval from Treasury (via `erc20ApprovalSetup`)
- [ ] Test V1 claimRewards reverts (RESERVESPENDER revoked)
- [ ] Test V1 deposit reverts: `cast send <V1> "deposit(address,uint256,uint256)" <KONDUX> 1000 0 --from <testWallet>` → REVERT
- [ ] Test V2 deposit works: `cast send <V2> "deposit(address,uint256,uint256)" <KONDUX> <amount> 0 --from <userWallet>` → SUCCESS
- [ ] Test V2 withdraw works for migrated deposit
- [ ] Test V2 claimRewards works for migrated deposit
- [ ] Test V2 stakeRewards works (compound) for migrated deposit
- [ ] V2 `calculateRewards()` returns correct values for migrated deposits
- [ ] V2 `calculateBoostPercentage()` works correctly with Founders/kNFT

---

## Phase 4: Post-Migration Monitoring

> **Goal:** Ensure V2 operates correctly under real usage for 48+ hours.

### Immediate (first hour)

- [ ] Monitor V2 for successful user transactions (deposit, withdraw, claim)
- [ ] Verify no unexpected reverts in V2 contract logs
- [ ] Etherscan event log shows `DepositImported` events from Phase 2
- [ ] Users can query their deposits via `userDeposits(id)` same as V1
- [ ] Users can query deposit list via `userDepositsIds(addr, index)` same as V1
- [ ] Helix balances unchanged (import doesn't mint/burn Helix)

### First 24 hours

- [ ] At least 1 successful deposit on V2 from a new user
- [ ] At least 1 successful withdrawal from V2 by a migrated user
- [ ] At least 1 successful compound (stakeRewards) on V2
- [ ] Rewards accruing correctly (compare `calculateRewards` with expected APR)
- [ ] No governor calls needed for emergency fixes
- [ ] Frontend updated to point to V2 address

### First 48 hours

- [ ] No reported issues from community
- [ ] Aggregate totalStaked growing (new deposits exceeding withdrawals)
- [ ] APR snapshot working: new deposits get current APR, old deposits keep imported APR
- [ ] If APR is changed, old deposits still use snapshot APR (verify with `getDepositAprSnapshot`)

---

## Phase 5: Cleanup & Documentation

> **Goal:** Update all references, archive V1.

### Steps

- [ ] Update `docs/deployments/` address books with V2 address
- [ ] Update frontend contract addresses
- [ ] Update subgraph indexer (if applicable) to track V2 events
- [ ] Update `docs/guides/staking-system.md` with V2 specifics (APR snapshots)
- [ ] Update `docs/guides/staking-v2-migration.md` — mark all checklist items complete
- [ ] Archive V1 deployment artifacts
- [ ] Verify V1's `RESERVESPENDER` was revoked in Phase 3 (should already be done)
- [ ] Consider revoking V1's `RESERVEDEPOSITOR` permission after confirming no further interactions needed

---

## Rollback Plan

### If Phase 1 fails (deploy):
- No impact. V1 unaffected. Fix issues and redeploy.

### If Phase 2 fails (import):
- V1 unaffected. Redeploy V2 from scratch if import data is corrupted.
- If partial import succeeded, can use `FORCE_IMPORT=true` to continue.

### If Phase 3 fails (shutdown):
- If V1 shutdown executed but V2 activation failed:
  - Re-grant `MINTER_ROLE` and `BURNER_ROLE` to V1 on Helix (governor tx)
  - Re-authorize KONDUX token on V1: `setAuthorizedERC20(KONDUX, true)` (governor tx)
  - V1 restored. Debug V2 issues separately.
- If V2 has issues after full activation:
  - Can deauthorize V2's KONDUX token to pause V2
  - Re-grant V1 roles to restore V1 operation
  - Users' V1 deposits still in V1 contract storage (never deleted)

### Emergency contacts

- Governor wallet holder: _______________
- Technical lead: _______________

---

## Data Integrity Guarantees

### What is preserved 1:1

| Data | V1 Location | V2 Location | Verification |
|------|-------------|-------------|--------------|
| Deposit struct (10 fields) | `userDeposits[id]` | `userDeposits[id]` | Field-by-field comparison |
| User deposit IDs | `userDepositsIds[addr][idx]` | `userDepositsIds[addr][idx]` | Iterate and compare |
| Total staked per token | `totalStaked[token]` | `totalStaked[token]` | Direct comparison |
| User staked per token | `userTotalStakedByCoin[addr][token]` | `userTotalStakedByCoin[addr][token]` | Direct comparison |
| Total rewarded | `totalRewarded[token]` | `totalRewarded[token]` | Direct comparison |
| User rewarded | `userTotalRewardedByCoin[addr][token]` | `userTotalRewardedByCoin[addr][token]` | Direct comparison |
| Deposit ID counter | `_depositIds` (slot 1) | `_depositIds` (slot 1) | Assembly read |
| APR per token | `aprERC20[token]` | `aprERC20[token]` + `_depositAprSnapshot[id]` | Both stored |
| All per-token config | 12+ mappings | Same mappings | Config sync step |
| Global config | timelock/boost arrays | Same arrays | Config sync step |

### What is NOT preserved (by design)

| Data | Reason |
|------|--------|
| `totalWithdrawalFees[token]` | Historical metric, not synced (V2 starts at 0) |
| V1 contract address references | V2 has its own address |
| Helix already minted for V1 deposits | Helix tokens remain in user wallets, unaffected |

### Helix continuity

Helix tokens minted by V1 deposits remain in user wallets. When a user withdraws from V2, V2 burns the correct Helix amount (based on `ratioStored` in the deposit). The Helix supply math stays consistent because:
- Import does NOT re-mint Helix (would double-count)
- Import preserves `ratioStored` per deposit (the ratio at time of original V1 deposit)
- V2 uses `ratioStored` for burn calculation on withdraw (same as V1)

---

## Gas Estimates

| Operation | Estimated Gas | Estimated Cost (30 gwei) |
|-----------|---------------|--------------------------|
| Deploy V2 | ~4,500,000 | ~0.135 ETH |
| Configure Helix + Treasury | ~500,000 | ~0.015 ETH |
| Import per batch (25 deposits) | ~2,000,000 | ~0.060 ETH |
| Import 100 deposits (4 batches) | ~8,000,000 | ~0.240 ETH |
| Import 200 deposits (8 batches) | ~16,000,000 | ~0.480 ETH |
| Shutdown V1 + Activate V2 | ~400,000 | ~0.012 ETH |
| **Total estimate (100 deposits)** | **~13,400,000** | **~0.402 ETH** |

> Actual costs depend on gas price at execution time. Import batches are the dominant cost. Adjust `STAKING_IMPORT_BATCH` if block gas limit is a concern (default 25 is conservative).

---

## FAQ

**Q: Can users still withdraw or claim rewards from V1 after migration?**  
A: No. V1 withdraw requires Helix burn (`BURNER_ROLE` revoked), and V1 claimRewards requires Treasury permission (`RESERVESPENDER` revoked). All V1 operations are fully disabled. Users interact with V2 where their deposits were imported.

**Q: What happens to rewards accrued during the migration window?**  
A: The `timeOfLastUpdate` field is preserved from V1. V2's `calculateRewards()` uses this timestamp, so no rewards are lost or double-counted.

**Q: What if the APR was changed between V1 and V2?**  
A: Imported deposits get an `aprSnapshot` equal to V1's APR at import time. Even if the global APR is later changed on V2, these deposits continue earning at the snapshot rate.

**Q: Can a deposit be imported twice?**  
A: No. `importDeposits()` reverts with `DepositAlreadyImported` if a deposit ID already has a non-zero staker in V2.

**Q: What about deposits made on V1 between import and shutdown?**  
A: These deposits exist only on V1 and will be inaccessible after shutdown. Minimize this window by executing Phases 2-3 in rapid succession and announcing a maintenance window.

**Q: Is V2 upgradeable?**  
A: No. Like V1, V2 is deployed as a standalone contract without a proxy. Future migrations would follow the same pattern.
