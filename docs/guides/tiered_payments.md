# Kondux Tiered Payments Smart Contract Documentation

## Overview
The `KonduxTieredPayments` contract implements a flexible micropayment system built on Ethereum. It enables users to deposit stablecoins for micropayments, supports tier-based pricing, applies NFT-based discounts, integrates a usage oracle, and distributes funds to providers with a royalty portion directed to Kondux.

## Contract Dependencies

- **OpenZeppelin AccessControl**: Role-based access control for security.
- **IERC20 & IERC721**: Interfaces for ERC-20 stablecoins and ERC-721 NFTs.

## Roles

- **GOVERNOR_ROLE**: Manages administrative tasks (e.g., adding stablecoins, updating lock periods).
- **UPDATER_ROLE**: Authorized to update usage records externally (e.g., oracle backend).

## Core Components

### Structs

- **UserPayment**: Tracks user deposits, usage, deposit time, and active status.
- **Tier**: Defines provider-specific pricing tiers based on usage.
- **ProviderInfo**: Provider registration details, including royalty and fallback pricing.

## Key Variables

- `ITreasury treasury`: Manages stablecoin deposits and withdrawals.
- `mapping(address => bool) stablecoinAccepted`: Accepted stablecoins.
- `mapping(address => UserPayment) userPayments`: User deposit and usage details.
- `mapping(address => ProviderInfo) providers`: Tracks provider details.
- `mapping(address => Tier[]) providerTiers`: Pricing tiers per provider.
- `address konduxRoyaltyAddress`: Default royalty recipient.
- `uint256 konduxRoyaltyBalance`: Accumulated royalty balance for Kondux.
- `address[] nftContracts`: NFT contracts eligible for discounts.
- `uint256 lockPeriod`: Time-lock duration for user deposits.
- `IUsageOracle usageOracle`: Optional external usage verification.

## Core Functionalities

### User Deposits

- Users deposit accepted stablecoins, triggering `deposit()`.
- Deposits have a lock period during which withdrawal is restricted.

## Usage Tracking and Billing

- Providers can define tiered pricing structures.
- Usage cost computed based on tiers; fallback rates apply beyond highest tier.
- Royalty deducted from each payment and routed to Kondux or provider-specified receiver.

## NFT-Based Discounts

- Users holding NFTs from `nftContracts` get configurable discounts (`nftDiscountBps`).

## Funds Management

### Deposits
- Managed via `deposit()` method, stablecoins transferred into treasury.
- User funds locked for a set `lockPeriod`.

### Withdrawals

- Users can withdraw unused stablecoins post lock period (`withdraw`).
- Providers withdraw earnings via `providerWithdraw()`.
- Kondux royalty withdrawal through `withdrawRoyalty()`.

## Provider Management

- Providers register/update settings (`registerProvider`) and tiers (`setProviderTiers`).
- Providers unregister through `unregisterProvider`.

## Usage Application

- Usage can be reported by UPDATERS or self-reported by users (`applyUsage`, `selfApplyUsage`).
- Payments and royalties calculated and distributed accordingly.

## Administrative Functions (Governor-Only)

- Manage accepted stablecoins (`setStablecoinAccepted`).
- Update lock period (`setLockPeriod`).
- Manage NFT contracts (`setNFTContracts`).
- Set usage oracle (`setUsageOracle`).
- Configure default royalties (`setDefaultRoyaltyBps`).
- Set NFT discount (`setNFTDiscountBps`).
- Change royalty receiver address (`setKonduxRoyaltyAddress`).

## Key Events

- `DepositMade`: User deposits stablecoins.
- `UsageApplied`: Usage applied to user deposits.
- `UnusedWithdrawn`: User withdrawals of unused deposits post lock period.
- `UsageOracleUpdated`: Usage oracle address updated.
- `ProviderRegistered`: Provider registration/updates.
- `ProviderTiersUpdated`: Changes in provider's tier pricing.
- `ProviderWithdrawn`: Provider withdrawals.
- `RoyaltyWithdrawn`: Royalty withdrawals by Kondux.

## Security & Access Control

- Employs OpenZeppelin's AccessControl for secure role-based management.
- Governor-controlled administrative functions prevent unauthorized changes.

## Functional Flow Summary

1. Users deposit stablecoins, initiating a lock period.
2. Providers register, define pricing tiers, and royalty structure.
3. Users incur usage fees calculated against tiers, optionally discounted by NFT holdings.
4. Usage fees distributed between provider (net earnings) and Kondux (royalties).
5. Users retrieve unused funds post-lock period.

This contract structure enables scalable, secure, and transparent micropayments optimized for diverse provider offerings and flexible discounting schemes.

