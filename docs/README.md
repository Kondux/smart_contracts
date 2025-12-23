# Kondux Smart Contracts Documentation

Welcome to the Kondux documentation hub. This directory contains comprehensive guides, technical references, and deployment information for the Kondux NFT ecosystem.

---

## Quick Navigation

| Category | Description |
|----------|-------------|
| [Core Contracts](#core-contracts) | NFT implementation, factory, and royalty system |
| [Token Systems](#token-systems) | KNDX, HELIX, and staking mechanics |
| [Operations](#operations) | Minting, deployment, and system flows |
| [Deployments](#deployments) | Contract addresses and deployment guides |

---

## Core Contracts

### NFT System (ERC721C)

| Document | Description |
|----------|-------------|
| [KonduxImplementation](guides/KonduxImplementation.md) | Main NFT contract with beacon proxy pattern, DNA system, and royalty enforcement |
| [kondux-royalty-model](kondux-royalty-model.md) | Royalty configuration, enforcement mechanics, and settlement flow |
| [nft_dna](guides/nft_dna.md) | 256-bit on-chain trait encoding system |

### Architecture Overview

```
KonduxBeaconFactory
    ├── UpgradeableBeacon → KonduxImplementation (logic)
    └── deployCloneWithSplitter()
            ├── BeaconProxy (collection)
            └── KonduxRoyaltySplitter (royalty distribution)
```

**Key Design Decisions:**
- **Beacon Proxy Pattern**: Single implementation, multiple collections, O(1) upgrades
- **ERC721C Compliance**: Limit Break standard for marketplace royalty enforcement
- **Royalty Splitter**: Automatic distribution to manufacturer/partner/creator

---

## Token Systems

### KNDX Token
The native utility token of the Kondux ecosystem, used for:
- Staking rewards
- Royalty payments
- Governance participation

### HELIX Token
| Document | Description |
|----------|-------------|
| [helix](guides/helix.md) | ERC20 token with transfer restrictions and role-based minting |

HELIX serves as a receipt token for staking, representing locked KNDX positions.

### Staking
| Document | Description |
|----------|-------------|
| [staking-system](guides/staking-system.md) | Complete staking guide: APR, boosts, locking periods, penalties |

**Staking Highlights:**
- Base APR: 25%
- NFT Boosts: Founder's Pass (+10%), kNFTs (+1-5% each, max 5)
- Lock periods: 30/90/180/365 days with increasing rewards
- HELIX receipt tokens at 10,000:1 ratio

---

## Operations

### Minting

| Document | Description |
|----------|-------------|
| [KonduxBatchMinter](guides/KonduxBatchMinter.md) | EIP-712 signed batch minting for gas-efficient operations |

**Minting Flow:**
1. Admin/minter signs EIP-712 voucher off-chain
2. User submits voucher + ETH to `mintBatchWithSignature`
3. Contract mints NFTs, forwards ETH to treasury

### System Flows

| Document | Description |
|----------|-------------|
| [omniforge-flow](omniforge-flow.md) | End-to-end deployment and minting orchestration diagram |

### Payments
| Document | Description |
|----------|-------------|
| [tiered_payments](guides/tiered_payments.md) | Micropayment system with tier-based pricing and NFT discounts |

---

## Deployments

### Mainnet Addresses

| Contract | Address |
|----------|---------|
| Factory | `0xa265a01205f304F2652277AaC924AB56D2e0Cf77` |
| Beacon | `0x21D1a52A17a1Df346Dd223Ef89D0e362Ee64b219` |
| Implementation | `0xd5E8Ac6284825D99dAE3d16Bef4537d4B665E1Be` |
| Collection | `0x167a45aaC7a4512089eC6d401547351d7c73e66F` |
| Splitter | `0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8` |
| Seaport 1.6 | `0x0000000000000068F116a894984e2DB1123eB395` |
| Transfer Validator | `0x721C008fdff27BF06E7E123956E2Fe03B63342e3` |

### Deployment Guides

| Document | Description |
|----------|-------------|
| [kondux-batchminter/README](deployments/kondux-batchminter/README.md) | Batch minter deployment playbook with Forge scripts |
| [kondux-batchminter/address-book](deployments/kondux-batchminter/address-book.json) | Deployment records and contract addresses |

---

## Contract Roles

### KonduxImplementation

| Role | Purpose |
|------|---------|
| `DEFAULT_ADMIN_ROLE` | Full admin access, can grant/revoke roles |
| `MINTER_ROLE` | Can mint new tokens |
| `DNA_MODIFIER_ROLE` | Can modify token DNA |

### KonduxBeaconFactory

| Role | Purpose |
|------|---------|
| `DEFAULT_ADMIN_ROLE` | Full admin, can upgrade implementation |
| `CLONE_DEPLOYER_ROLE` | Can deploy new collections |
| `FEE_ADMIN_ROLE` | Can manage splitter fees |

### KonduxRoyaltySplitter

| Role | Purpose |
|------|---------|
| `ADMIN_ROLE` | Full splitter admin |
| `DISTRIBUTOR_ROLE` | Can register creators |
| `COLLECTION_ROLE` | The NFT contract |
| `FEE_ADMIN_ROLE` | Can modify fee splits |

---

## Royalty System

### Distribution Flow

```
Sale Price (e.g., 1 ETH)
    ├── Seller receives: ~89% (price - royalty - marketplace fee)
    ├── OpenSea: 1% marketplace fee
    └── Splitter: 10% royalty
            ├── Manufacturer: 5% → treasury wallet
            ├── Partner: 0% → partner wallet (or manufacturer if unset)
            └── Creator: 5% → token creator wallet
```

### Configuration

- Total royalty: 10% (1000 basis points)
- Configurable splits between manufacturer/partner/creator
- Per-token creator assignment during mint
- ERC2981 compliance for marketplace integration

---

## Development

### Environment Setup

**Windows + WSL:**
```bash
# Build contracts
wsl -e bash -c "cd /mnt/d/git/smart_contracts && ~/.foundry/bin/forge build"

# Run tests
wsl -e bash -c "cd /mnt/d/git/smart_contracts && ~/.foundry/bin/forge test -vv"

# Specific test
wsl -e bash -c "cd /mnt/d/git/smart_contracts && ~/.foundry/bin/forge test --match-contract SeaportSplitterE2E -vvvv"
```

**PowerShell for Node.js scripts:**
```powershell
cd d:\git\smart_contracts
node scripts/util/listOnOpenSea.js
```

### Key Test Files

| File | Purpose |
|------|---------|
| `forge-tests/SeaportSplitterE2E.t.sol` | End-to-end Seaport royalty integration tests |
| `forge-tests/KonduxImplementation.t.sol` | NFT implementation unit tests |

---

## Legacy Documentation

These files document previous system versions and are kept for historical reference:

| Document | Description |
|----------|-------------|
| [kNFT-legacy](guides/kNFT-legacy.md) | Original kNFT with KNDX-based royalty enforcement |
| [kNFT_Factory-legacy](guides/kNFT_Factory-legacy.md) | Original factory pattern before beacon architecture |

---

## Related Resources

- **CLAUDE.md** - AI agent instructions for this codebase
- **AGENTS.md** - General AI agent guidelines
- **.claude/** - Slash commands and skills configuration

---

## Contributing

When updating documentation:
1. Keep technical details accurate with contract code
2. Update mainnet addresses when contracts are redeployed
3. Maintain cross-references between related documents
4. Archive deprecated docs with `-legacy` suffix
