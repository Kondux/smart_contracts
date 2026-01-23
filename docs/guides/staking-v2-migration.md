# StakingV2 Migration Guide

**Last Updated:** 2026-01-19  
**Status:** Ready for Deployment

## Overview

This guide outlines the complete process for migrating from StakingV1 to StakingV2, including how to shut down V1 and force all users to withdraw through V2 while honoring their original deposit terms (25% APR, timelock bonuses).

## Architecture

### StakingV2 Features

- **Per-Deposit APR Snapshots**: Each deposit stores its APR at creation time
- **Legacy Import**: `importDeposits()` function to batch import V1 deposits with original rates
- **Configurable New Rates**: New deposits after migration can have different (lower) APR
- **Full V1 Compatibility**: Honors timelock bonuses, Founder/kNFT boosts, all existing mechanics

### Key Contracts

| Contract | Address (Mainnet) | Purpose |
|----------|-------------------|---------|
| StakingV1 | `0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC` | Legacy staking (to be deprecated) |
| StakingV2 | TBD after deployment | New staking with per-deposit APR |
| Helix | `0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4` | Collateral token (shared) |
| Kondux Token | `0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1` | Staking token (shared) |

## Migration Process

### Phase 1: Deploy StakingV2

```bash
# Deploy StakingV2 to mainnet
forge script scripts/solidity/deploy/DeployStakingV2.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --broadcast \
    --verify

# Save deployed address
export STAKING_V2_ADDRESS=<deployed_address>
```

**Output:** StakingV2 deployed, configured with Helix/Treasury, but NOT yet granted roles.

### Phase 2: Import V1 Deposits

**Important:** This must be done BEFORE shutting down V1.

```bash
# Run migration script to import all V1 deposits
forge script scripts/solidity/deploy/ImportV1Deposits.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --broadcast

# This will:
# - Read all deposits from V1
# - Call importDeposits() in batches of 10-50
# - Preserve: deposited amount, timelock, APR (25%), rewards, boost tier
```

**Result:** V2 has exact copies of all V1 deposits with same deposit IDs.

### Phase 3: Update ShutdownStakingV1.s.sol

Before running shutdown, update the script with V2 address:

```solidity
// In scripts/solidity/deploy/ShutdownStakingV1.s.sol
// Line ~70, update:
stakingV2: 0x<YOUR_DEPLOYED_V2_ADDRESS>
```

### Phase 4: Execute Shutdown

```bash
# Update script with V2 address first!
# Then run shutdown script
forge script scripts/solidity/deploy/ShutdownStakingV1.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --broadcast

# This executes (as Governor/Helix Admin):
# 1. stakingV1.setAuthorizedERC20(KONDUX, false)     [Prevents new deposits]
# 2. helix.setRole(MINTER_ROLE, V1, false)           [Prevents restaking]
# 3. helix.setRole(BURNER_ROLE, V1, false)           [Prevents withdrawals]
# 4. helix.setRole(MINTER_ROLE, V2, true)            [Enables V2 deposits]
# 5. helix.setRole(BURNER_ROLE, V2, true)            [Enables V2 withdrawals]
```

**Result:** V1 completely frozen, V2 fully operational.

### Phase 5: Set New APR (Optional)

If you want new deposits to have a lower rate:

```bash
# As Governor, call on StakingV2:
cast send $STAKING_V2_ADDRESS \
    "setAPR(uint256,address)" \
    1500 \  # 15% APR (1500 basis points)
    $KONDUX_TOKEN \
    --rpc-url $MAINNET_RPC_URL \
    --private-key $GOVERNOR_PK
```

**Result:** New deposits get 15% APR, imported V1 deposits keep 25% APR.

### Phase 6: Communication

Announce to users:

> **StakingV1 Migrated to StakingV2**
> 
> **Your positions are safe and unchanged:**
> - Same 25% APR
> - Same timelock expiration dates
> - Same timelock bonuses (0%, 1%, 3%, 9%)
> - Same Founder/kNFT boosts
> - Same deposit IDs
> 
> **What's different:**
> - Use V2 contract: `0x<STAKING_V2_ADDRESS>`
> - V1 is now read-only (no deposits/withdrawals)
> - All withdrawals must go through V2
> 
> **For new deposits:**
> - New deposits earn 15% APR (lower than legacy 25%)
> - Legacy positions keep 25% forever

## Testing

### E2E Migration Test (Recommended)

The comprehensive E2E test simulates the complete migration flow on forked mainnet with admin impersonation:

```bash
# Run the complete E2E migration test
forge test --match-contract StakingV2MigrationE2ETest --match-test test_E2E_CompleteMigrationWithUserScenarios -vvv
```

#### What the E2E Test Covers

The test executes 9 phases simulating the real migration:

| Phase | Description | Verifications |
|-------|-------------|---------------|
| **Phase 1** | Create V1 deposits before migration | Users can deposit in V1, Helix minted |
| **Phase 2** | Deploy and configure StakingV2 | V2 deployed with V1 config, Treasury approved |
| **Phase 3** | Import V1 deposits to V2 | Deposits imported with APR snapshots preserved |
| **Phase 4** | Shutdown V1 and enable V2 | V1 deauthorized, roles revoked/granted |
| **Phase 5** | Verify V1 operations blocked | Deposit, withdrawal, restaking all revert |
| **Phase 6** | Migrated user withdraws from V2 | Imported deposits can withdraw successfully |
| **Phase 7** | New user deposits in V2 | Fresh deposits work, Helix minted |
| **Phase 8** | APR change and effects | Old deposits keep 25%, new deposits get 15% |
| **Phase 9** | Final verification | All state assertions pass |

#### Key Test Scenarios

**1. V1 Operations Blocked After Shutdown:**
```solidity
// Deposit blocked
vm.expectRevert("Token not authorized");
stakingV1.deposit(amount, 0, KONDUX_TOKEN);

// Withdrawal blocked (no BURNER_ROLE)
vm.expectRevert();
stakingV1.withdraw(amount, depositId);

// Restaking blocked (no MINTER_ROLE)
vm.expectRevert();
stakingV1.stakeRewards(depositId);
```

**2. Migrated Deposits Work in V2:**
```solidity
// Import preserves APR snapshot
(uint256 aprSnapshot, bool hasSnapshot) = stakingV2.getDepositAprSnapshot(depositId);
assertTrue(hasSnapshot);
assertEq(aprSnapshot, 2500); // 25% preserved

// Withdrawal works
stakingV2.withdraw(amount, depositId);
```

**3. APR Isolation Verified:**
```solidity
// Change global APR to 15%
vm.prank(governor);
stakingV2.setAPR(1500, KONDUX_TOKEN);

// Old deposits keep 25%
(uint256 oldApr,) = stakingV2.getDepositAprSnapshot(oldDepositId);
assertEq(oldApr, 2500);

// New deposits get 15%
uint256 newDepositId = stakingV2.deposit(amount, 0, KONDUX_TOKEN);
(uint256 newApr,) = stakingV2.getDepositAprSnapshot(newDepositId);
assertEq(newApr, 1500);

// Restaking blocked when APR changed
vm.expectRevert(); // APRChangedForDeposit
stakingV2.stakeRewards(oldDepositId);
```

### Fork Test (Read-Only Verification)

Quick verification of current V1 state without executing changes:

```bash
forge test --match-contract StakingV1ShutdownTest --match-test test_VerifyShutdownLogic -vv
```

**Expected output:**
```
V1 Token Authorized: true
V1 Has MINTER_ROLE: true
V1 Has BURNER_ROLE: true
V1 Total Staked: <current amount>
```

### Unit Tests

```bash
# StakingV2 APR snapshot tests
forge test --match-contract StakingV2Test -vv

# StakingV2 import tests
forge test --match-contract StakingV2MigrationForkTest -vv

# All staking tests
forge test --match-path "forge-tests/Staking*" -vv
```

### Test Environment Variables

```bash
# Optional: Use your own RPC for faster tests
export MAINNET_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY

# Run with specific fork block
forge test --fork-block-number 19000000 --match-contract StakingV2MigrationE2ETest -vvv
```

## Rollback Plan

If issues arise, the shutdown can be reversed:

```bash
# Re-enable V1 (as Governor/Helix Admin)
stakingV1.setAuthorizedERC20(KONDUX_TOKEN, true)
helix.setRole(MINTER_ROLE, STAKING_V1, true)
helix.setRole(BURNER_ROLE, STAKING_V1, true)

# Disable V2
helix.setRole(MINTER_ROLE, STAKING_V2, false)
helix.setRole(BURNER_ROLE, STAKING_V2, false)
```

**Note:** This should only be done if V2 has critical bugs. Users may have already interacted with V2.

## Post-Migration Monitoring

### Week 1
- Monitor V2 deposit/withdrawal activity
- Verify Helix mint/burn balance
- Check Treasury token flows
- Monitor gas costs

### Month 1
- Track user migration rate
- Verify APR calculations match expected
- Ensure timelock enforcement working
- Monitor for any edge cases

### Ongoing
- V1 should show zero activity
- V2 becomes primary staking contract
- Consider deprecating V1 frontend after 6 months

## FAQ

**Q: What happens to my unclaimed rewards in V1?**  
A: They're imported to V2. You can claim them from V2.

**Q: Can I still see my old deposit ID?**  
A: Yes, V2 uses the same deposit IDs as V1.

**Q: Will my timelock reset?**  
A: No, your timelock expiration date is preserved exactly.

**Q: What if I try to withdraw from V1?**  
A: The transaction will revert (V1 no longer has BURNER_ROLE on Helix).

**Q: Can new users deposit to V1?**  
A: No, V1 token authorization is disabled.

**Q: Why is my new deposit earning less than my old one?**  
A: New deposits earn the updated APR (15%), while imported V1 deposits keep their original 25% APR.

## Checklist

- [ ] Deploy StakingV2 to mainnet
- [ ] Verify StakingV2 on Etherscan
- [ ] Import all V1 deposits to V2
- [ ] Update ShutdownStakingV1.s.sol with V2 address
- [ ] Execute shutdown script
- [ ] Verify V1 fully disabled (run fork test)
- [ ] Verify V2 fully enabled (test deposit/withdrawal)
- [ ] Set new APR on V2 (if desired)
- [ ] Update frontend to point to V2
- [ ] Announce migration to community
- [ ] Monitor V2 for 1 week
- [ ] Deprecate V1 frontend

## Files

| File | Purpose |
|------|---------|
| `contracts/StakingV2.sol` | New staking contract with per-deposit APR |
| `scripts/solidity/deploy/DeployStakingV2.s.sol` | Deployment script |
| `scripts/solidity/deploy/ShutdownStakingV1.s.sol` | Shutdown + V2 enablement script |
| `scripts/shell/test-shutdown-fork.sh` | Fork testing helper |
| `forge-tests/StakingV2.t.sol` | Unit tests for V2 features |
| `forge-tests/StakingV2Migration.t.sol` | V1→V2 import tests |
| `forge-tests/StakingV1Shutdown.t.sol` | Shutdown verification tests |

## Support

For issues during migration:
1. Check transaction on Etherscan
2. Verify contract state (roles, balances)
3. Run fork tests to simulate fix
4. Use rollback plan if critical

---

**Status:** Ready for production deployment. All code complete and tested.
