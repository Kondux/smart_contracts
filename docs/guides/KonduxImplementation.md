# Executive Summary of **KonduxImplementation** (kNFT) Contract

## Table of Contents

- [Executive Summary of **KonduxImplementation** (kNFT) Contract](#executivesummary-of-konduximplementation-knft-contract)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Why a Clone‑Model?](#why-a-clonemodel)
  - [Quick‑Start Guide: Cloning \& Configuration](#quickstart-guide-cloning--configuration)
    - [1. Clone via Factory (pseudo‑JS)](#1-clone-via-factory-pseudojs)
    - [2. Post‑clone Setup Checklist](#2-postclone-setup-checklist)
  - [Leasing / Rental Flow (EIP‑4907)](#leasing--rental-flow-eip4907)
  - [Handy **Getter / View** Functions for Front‑End Integrations](#handy-getter--view-functions-for-frontend-integrations)
    - [Example: Display royalty info for a token](#example-display-royalty-info-for-a-token)
    - [Responsive UI Pattern](#responsive-ui-pattern)
  - [Real‑World Use‑Cases](#realworld-usecases)

---

## Introduction

The **KonduxImplementation** contract is a feature‑rich, upgrade‑ready ERC‑721 collection template designed to be **cloned once per collection** via EIP‑1167 minimal proxies and managed from the **Kondux Contract Factory**. It provides a comprehensive set of tools for NFT creators, including:

| Capability group                          | Main functions / storage                                                                                                                                                              | Purpose                                                                                                            |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Upgradeable ERC‑721 core**              | `ERC721Upgradeable`, `ERC721EnumerableUpgradeable`, `ERC721BurnableUpgradeable`, `setBaseURI`, `tokenURI`                                                                             | Standard NFT minting, enumeration, burning, and metadata management with future‑proof upgrades.                    |
| **Role‑based access control**             | Admin, `MINTER_ROLE`, `DNA_MODIFIER_ROLE`; `setRole`                                                                                                                                  | Fine‑grained, on‑chain permissioning for minting, DNA editing, and administration.                                 |
| **Per‑token DNA system**                  | `safeMint`, `setDna`, `batchSetDna`, `readGen`, `writeGen`                                                                                                                            | 256‑bit immutable/mutable DNA enabling on‑chain genetics, game stats, or trait control without off‑chain look‑ups. |
| **Royalty & fee engine**                  | ETH‑denominated per‑token royalty (`royaltyETHWei`) auto‑converted to KNDX using Uni‑V2 pool reserves; configurable manufacturer/partner/creator splits; multiple exemption switches. |                                                                                                                    |
| **Marketplace‑level royalty enforcement** | `_enforceRoyalty` hook in `_update` blocks transfers when royalties are unpaid, guaranteeing creator & treasury revenues without relying on off‑chain marketplaces.                   |                                                                                                                    |
| **Toggle‑driven feature flags**           | `royaltyEnforcementEnabled`, `founderPassExemptEnabled`, `mintedOwnerExemptEnabled`, `treasuryFeeEnabled`, `eip4907Enabled`, `freeMinting` allow collections to evolve post‑launch.   |                                                                                                                    |
| **Leasing (EIP‑4907)**                    | `setUser`, `userOf`, `userExpires`, `eip4907Enabled`                                                                                                                                  | Time‑boxed assignment of a “user” distinct from owner, enabling rentals, subscriptions, and delegation.            |
| **Treasury & partner routing**            | `setAddresses`, `setRoyaltySplits`, `setPartnerWallet`                                                                                                                                | Route liquidity & royalty flows to Kondux treasury, partners, founders, or creators.                               |
| **Emergency administration**              | `emergencyWithdrawToken`, `emergencyWithdrawNFT`                                                                                                                                      | Safety valves for stuck funds/assets.                                                                              |
| **On‑chain price oracle**                 | `getKndxForEth` + `_getReserves`                                                                                                                                                      | Instant ETH→KNDX conversion based on live Uni‑V2 pool—used for pricing royalties and can be repurposed for mints.  |

---

## Why a Clone‑Model?

Kondux deploys the **implementation once**, then creates new collections with **EIP‑1167 minimal proxies** (“clones”).

| Benefit                            | Impact                                                                                                                                                                                                    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **\~10× cheaper deployment gas**   | Clones store only a 45‑byte pointer to the implementation, ideal for frequent collection launches.                                                                                                        |
| **Uniform, battle‑tested logic**   | All collections inherit identical audited code, reducing attack surface.                                                                                                                                  |
| **Factory orchestration**          | The **Kondux Contract Factory** mints a new proxy, then immediately calls `initialize`—guaranteeing every collection is properly parameterised before going live.                                         |
| **Upgradeable & hot‑fix friendly** | Should a critical bug be found, a patched implementation can be rolled out and new collections can point to the new logic while existing ones remain unaffected (or can be migrated via Factory tooling). |
| **Predictable byte‑code**          | Facilitates deterministic addresses (CREATE2) and easy integration with front ends & sub‑graphs.                                                                                                          |

The **KonduxImplementation** obeys Factory conventions:

1. **Constructor is disabled** (`_disableInitializers`) preventing accidental direct deployments.
2. **All state is set in `initialize`**, matching the Factory’s post‑clone “init‑then‑config” pipeline.
3. **Storage gaps** (`uint256[50] private __gap`) leave room for future upgrades without memory collisions.

---

## Quick‑Start Guide: Cloning & Configuration

> **Assumptions**: You are the Factory admin, have compiled byte‑code and hold the addresses for WETH, KNDX, Founders Pass, Treasury, and Uniswap pair.

### 1. Clone via Factory (pseudo‑JS)

```solidity
address newCollection = KonduxFactory.cloneCollection(
    "Cool K‑Dragons",
    "KDRGN",
    uniswapV2Pair,
    WETH,
    KNDX,
    FOUNDERS_PASS,
    KONDUX_TREASURY,
    5000            // maxSupply
);
```

Behind the scenes the Factory:

1. `createClone(implementation)`.
2. `initialize(...)` with arguments above.
3. Grants itself admin so you can manage roles later.

### 2. Post‑clone Setup Checklist

| Action                                | When / Why                                                         | API call                                 |
| ------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------- |
| **Set baseUri**                       | After uploading metadata to IPFS / Arweave                         | `setBaseURI("ipfs://CID/")`              |
| **Adjust royalties**                  | Change default 0.001 ETH or customise per token                    | `setTokenRoyaltyEth(tokenId, amountWei)` |
| **Tune royalty splits**               | Different partner/manufacturer deals                               | `setRoyaltySplits(4500, 2500, 3000)`     |
| **Switch treasury fee**               | Promotional period with zero platform fee                          | `setTreasuryFeeEnabled(false)`           |
| **Enable free minting**               | Allow open mint or disable to restrict to `MINTER_ROLE`            | `setFreeMinting(true/false)`             |
| **Add/Remove minters or DNA editors** | Delegate mint bots or artist wallets                               | `setRole(MINTER_ROLE, addr, true)`       |
| **Update partner wallet**             | Direct partner share to a new multisig                             | `setPartnerWallet(newAddress)`           |
| **Toggle royalty enforcement**        | Interop testing on non‑royalty markets                             | `setRoyaltyEnforcement(false)`           |
| **Change denominator**                | Move from basis‑points (10 000) to e.g. 1 000 000 for finer splits | `changeDenominator(1_000_000)`           |
| **Update external addresses**         | If Treasury or KNDX token migrates                                 | `setAddresses(...)`                      |


---

## Leasing / Rental Flow (EIP‑4907)

**Concept**: Ownership (transferable) vs *User* (time‑limited licence).
The owner or an approved operator may call:

```solidity
setUser(tokenId, renter, uint64(expiryTimestamp));
```

* Until `expiryTimestamp`, `userOf(tokenId)` returns the renter’s address.
* Marketplaces supporting 4907 can display “rented” status, preventing unauthorized sales.
* On transfer, `_update` **clears user data automatically**, avoiding dangling leases.

---

## Handy **Getter / View** Functions for Front‑End Integrations

A Kondux kNFT proxy exposes a rich set of inexpensive **`view`** calls that let dApps, indexers and wallets surface collection‑specific UX without custom sub‑graphs.  Below are the ones most teams ask for.

| What you need to show in the UI                 | Call / Variable                                                                                  | Notes                                                                              |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| **Creator (original minter) royalty recipient** | `royaltyOwnerOf(tokenId) → address`                                                              | Set once on `safeMint`; can later be reassigned by that address or an admin.       |
| **Fixed royalty amount (in ETH wei)**           | `royaltyETHWei(tokenId) → uint256`                                                               | Always denominated in wei; front end can  ➜  `getKndxForEth` to preview KNDX owed. |
| **Instant ETH→KNDX quote**                      | `getKndxForEth(ethWei) → uint256`                                                                | Reads live Uniswap‑V2 reserves—no oracle needed.                                   |
| **DNA / trait blob (256 bits)**                 | `getDna(tokenId) → uint256`<br>`readGen(tokenId, start, end) → int256`                           | Use `readGen` to pull specific byte ranges (e.g. gene 5‑7).                        |
| **Leasing status (EIP‑4907)**                   | `userOf(tokenId) → address`<br>`userExpires(tokenId) → uint256`                                  | Returns `0x0` if rental expired or feature disabled.                               |
| **Whether a feature is toggled on**             | Public booleans:<br>`royaltyEnforcementEnabled`<br>`freeMinting`<br>`eip4907Enabled`, etc.       | Surfaces collection governance decisions in real time.                             |
| **Royalty split percentages**                   | `manufacturerCutBP`, `partnerCutBP`, `creatorCutBP`, `denominator`                               | Display a pie‑chart of how transfer fees are routed.                               |
| **Partner wallet (if set)**                     | `partnerWallet → address`                                                                        | Falls back to `royaltyOwnerOf(tokenId)` on‑chain if `0x0`.                         |
| **Current supply stats**                        | `totalSupply()` (from ERC‑721 Enumerable)<br>`maxSupply`                                         | Useful for mint progress bars.                                                     |
| **Interface support probe**                     | `supportsInterface(0xad092b5c)` → leasing?<br>`supportsInterface(0x49064906)` → metadata update? | Allows dynamic feature detection across clones.                                    |
| **Base metadata URI**                           | `baseURI`                                                                                        | Good for IPFS pin‑checks or off‑chain cache invalidation.                          |

### Example: Display royalty info for a token

```js
const owner      = await kNFT.royaltyOwnerOf(tokenId);
const ethRoyalty = await kNFT.royaltyETHWei(tokenId);
const kndxDue    = await kNFT.getKndxForEth(ethRoyalty);

console.log(`On next transfer ${formatWei(ethRoyalty)} ETH ≈ ${formatUnits(kndxDue, 18)} KNDX
will be split between creator / partner / treasury.`);
```

### Responsive UI Pattern

1. **Detect capabilities** at load‑time with `supportsInterface`.
2. **Subscribe to EIP‑4906 `MetadataUpdate`** events to auto‑refresh images or traits.
3. **Cache‑layer**: because all getters are pure on‑chain reads, you can safely memoize responses until a relevant event fires.

By leaning on these built‑in getters, integrators avoid custom Graph schemas and deliver feature‑aware experiences that stay in sync with every Kondux collection, present and future.

---

## Real‑World Use‑Cases

| Scenario                          | How it works in kNFT                                                                                 | Business value                                                 |
| --------------------------------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **In‑game item rentals**          | Game dev mints swords; players rent using `setUser`; smart contract enforces expiry.                 | Earn yield on idle assets; low‑risk trial for new players.     |
| **Season‑pass memberships**       | Music venue sells kNFT; holders lease their access to friends for specific concerts.                 | Maximises utilisation without permanent transfer.              |
| **Digital twins for IoT devices** | EV manufacturer mints kNFT per vehicle; rental agencies call `setUser` for each ride‑share customer. | On‑chain audit trail of vehicle usage, easy revenue splitting. |
| **IP licensing / brand collabs**  | Fashion brand grants 1‑month usage rights of a design via `setUser`; expiry auto‑revokes.            | Rapid, automated micro‑licensing without lawyers.              |

*Opt‑out*: If a collection never needs rentals, an admin can permanently disable 4907 by `setEip4907Enabled(false)` to save gas on transfers.


