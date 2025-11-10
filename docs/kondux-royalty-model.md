# Kondux Royalty Model

This document explains how secondary-market royalties are modeled, enforced, and administered in `KonduxImplementation.sol`. It is intended for product, engineering, and compliance stakeholders who need a concise but complete overview of the mechanism and its operational levers.

---

## What "Royalties" Mean Here

- **Per-token royalty breakdown** lives in `_tokenRoyalties[tokenId]`, a struct that records raw wei allocations for the creator, manufacturer (treasury), and partner categories. For legacy consumers we still mirror the sum of those fields in `royaltyETHWei[tokenId]`. Fresh mints seed the creator share with `1e15` wei (0.001 ETH) and default the other categories to zero unless administrators change the defaults.
- **Global defaults and caps** (`default{Creator,Manufacturer,Partner}RoyaltyWei` and `global{Creator,Manufacturer,Partner}RoyaltyCap`) bound every update path. Admins can tighten caps, adjust defaults, and the contract enforces that no per-token write exceeds the configured ceiling.
- **Royalty owner identity** is tracked by `royaltyOwnerOf[tokenId]`. Newly minted tokens assign the recipient as the royalty owner. Control can later be transferred either by the administrator or by the current royalty owner.
- **Settlement asset** is **KNDX**, not ETH. When a token is resold with royalty enforcement enabled, the seller must remit KNDX representing the ETH-denominated royalty.
- **Price discovery** is performed on-chain using the configured WETH/KNDX Uniswap V2 pair.

### Conversion Formula

Let `(reserveWETH, reserveKNDX)` be the current reserves returned by `uniswapV2Pair.getReserves()`. For a royalty of `ethRoyaltyWei`:

```
KNDX_required = (ethRoyaltyWei * reserveKNDX) / reserveWETH
```

The contract caches neither reserves nor prices; each enforcement reads fresh reserves, making the calculation deterministic for the transaction.

### Per-Category Amounts

Each token stores a concrete wei amount for the creator, manufacturer, and partner categories. Administrators shape the defaults for new mints with `setGlobalRoyaltyDefaults`, and both admins and creators can override specific tokens by calling `adminSetTokenRoyalties`, `setTokenCreatorRoyalty`, `setTokenManufacturerRoyalty`, or `setTokenPartnerRoyalty`. Whatever values are stored are the exact amounts enforced on transfer—no denominators or percentage math remain in the contract. When the partner wallet is unset, the partner share automatically routes to the creator.

### Enforcement Toggles

- `royaltyEnforcementEnabled`: master switch for all royalty logic.
- `creatorRoyaltyEnabled`: globally enables or disables creator payouts while leaving other categories intact.
- `partnerRoyaltyEnabled`: mirrors the creator toggle for the partner allocation; useful when no external partner participates.
- `manufacturerRoyaltyEnabled` and `treasuryFeeEnabled`: the manufacturer share only flows when both switches are true (they are updated together by `setManufacturerRoyaltyEnabled`). Disabling them also turns off the historical treasury fee flag for backwards compatibility.
- `mintedOwnerExemptEnabled`: exempts the original minter (current royalty owner) from paying royalties when they transfer their own token.
- `founderPassExemptEnabled`: exempts senders who hold a founders pass.

### Caps and Defaults

- `setGlobalRoyaltyDefaults` lets administrators update the raw wei amounts that seed each freshly minted token. These defaults must remain within the currently configured caps.
- `setGlobalRoyaltyCaps` provides hard ceilings for creator, manufacturer, and partner allocations. Every setter (admin, creator, or category-specific) checks the cap before mutating storage, preventing runaway payouts.
- Lowering caps requires first updating defaults so the new ceiling is not below an active default. This sequence is enforced on-chain to avoid accidental lockouts during configuration changes.
- Setting a category to zero (either via defaults or per-token amounts) allows `_enforceRoyalty` to short-circuit and skip reserve reads, saving gas on zero-royalty or single-category flows.

All toggles are controllable through the `onlyAdmin` guard (i.e., `DEFAULT_ADMIN_ROLE`).

### Security Check During Transfers

When a transfer would trigger royalties, `_enforceRoyalty` verifies that the sender has provided a KNDX allowance covering the computed `requiredKndx`. Insufficient allowance causes the transfer to revert, guaranteeing payment before ownership is reassigned.

---

## Why This Design

### Gas Efficiency

- Reads reserves directly from the Uniswap pair, avoiding router calls, swaps, or off-chain price feeds.
- Performs at most three `ERC20.transferFrom` calls per enforced transfer, keeping execution cost predictable.
- Keeps state interactions minimal (single mapping updates), which helps stay under EVM stack limits and contract size ceilings.
- Zero-value paths (either because categories are disabled or configured to 0) short-circuit before reserve reads, eliminating unnecessary external calls.

### Contract Size and Complexity

- Uses simple mappings, booleans, and arithmetic to remain within upgradeable-contract size constraints.
- Royalty logic is isolated inside `_enforceRoyalty`, avoiding deep call stacks and keeping the proxy implementation audit-friendly.

### Determinism and Transparency

- All inputs to the royalty calculation are on-chain and queryable (royalty amount, partner wallet, splits, reserves).
- No external services or mutable off-chain configuration influence payouts.

### Operational Control

- `AccessControlUpgradeable` restricts critical configuration to designated administrators.
- Royalty owners can self-manage per-token royalties with `setTokenRoyaltyEth` (or by delegating ownership through `setRoyaltyOwner`), while admins retain `adminSetTokenRoyalties` and the category-specific setters for recovery workflows.
- Global levers `setGlobalRoyaltyDefaults` and `setGlobalRoyaltyCaps` make rollout-wide adjustments predictable and enforceable.

---

## Example Royalty Scenarios

Assumptions for illustration:

- `royaltyETHWei[tokenId] = 1e16` (0.01 ETH per transfer).
- Current Uniswap reserves imply `0.01 ETH = 250 KNDX`.
- Per-token breakdown for the example: manufacturer 0.004 ETH, partner 0.003 ETH, creator 0.003 ETH (totaling 0.01 ETH).

| Scenario | Required KNDX | Kondux Treasury | Partner Wallet | Creator/IP Owner | Notes |
|----------|---------------|-----------------|----------------|------------------|-------|
| Treasury fee ON, partner set | 250 | 100 | 75 | 75 | Manufacturer share enabled. |
| Treasury fee OFF | 250 | 0 | 75 | 175 | Treasury slice suppressed; remainder flows to creator. |
| No partner wallet configured | 250 | 100 | 0 (rerouted) | 150 | Partner share defaults to creator address. |
| Creator toggle OFF | 175 | 100 | 75 | 0 | Creator share globally disabled; total owed shrinks accordingly. |
| Partner toggle OFF | 175 | 100 | 0 | 75 | Partner share globally disabled; amounts are not rerouted. |
| Exempt transfer (minted owner or founders pass) | 0 | 0 | 0 | 0 | Royalty skipped entirely; no KNDX moves. |

> **Allowance reminder:** Before an enforced transfer, the sender must approve at least `requiredKndx` to the contract. Otherwise, `_enforceRoyalty` reverts the transfer.

---

## Security and Transparency Considerations

### Role-Based Administration

- Only addresses with `DEFAULT_ADMIN_ROLE` may adjust the treasury, WETH/KNDX addresses, Uniswap pair, toggles, and split parameters.
- Each token's royalty owner may update their `royaltyETHWei` or delegate ownership. Admins can override in recovery scenarios.

### On-Chain Enforcement

- Royalty collection is guaranteed because transfers revert unless the allowance test passes.
- Uses standard `ERC20.transferFrom` flows, minimizing reentrancy vectors and keeping execution paths auditable.

### Trusted Token Set

- Administrators configure the KNDX token and Uniswap pair addresses. Deployments should ensure these point to liquid, whitelisted contracts to preserve price accuracy.

### Observability

- Public state exposes per-token royalty breakdowns, per-category toggles, and partner wallet configuration.
- Events (`RoleChanged`, `MetadataUpdate`, `TokenRoyaltyUpdated`, etc.) provide an immutable trail of configuration changes.

---

## Additional Notes and Best Practices

- **Graceful Upgrades:** Because royalties rely on live Uniswap reserves, ensure the configured pair contract remains active and sufficiently liquid. If migrating liquidity pools, update addresses atomically.
- **Partner Wallet Rotation:** When rotating the partner wallet, communicate the change with stakeholders to reflect new revenue-sharing relationships.
- **Monitoring:** Track failed transfers in logs; repeated reverts may indicate insufficient allowances or partner wallet misconfiguration.
- **Testing:** Exercise edge cases such as small reserve values, repeated category toggling, and cap boundary conditions before production deployments.

For deeper implementation details, review `_enforceRoyalty`, `getKndxForEth`, and the admin setters in `contracts/KonduxImplementation.sol`.
