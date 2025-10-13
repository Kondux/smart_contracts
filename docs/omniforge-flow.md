# Omniforge Deployment & Minting Flow

```mermaid
flowchart TD
    Creator([Creator / Studio<br/>uploads hero 3D asset]) --> Wizard[Omniforge intake wizard<br/>asset prep & metadata capture]
    Wizard --> GDN[NVIDIA Graphics Delivery Network<br/>edge optimisation & QA]
    Wizard --> Offering[Commercial blueprint<br/>supply, tiers, royalty mix]
    Offering --> Decision{Launch new<br/>Kondux collection?}

    subgraph Automated Onchain Orchestration
        Logic[KonduxImplementation<br/>immutable logic on mainnet]
        DeployProxy[Deploy ERC1967 Proxy<br/>initialise with blueprint]
        Proxy[Kondux kNFT Proxy<br/>per creator collection]
        BatchConfig[Wire KonduxBatchMinter<br/>setKNFT + role programme]
        AddressBook[Update Omniforge inventory<br/>collections, minters, vaults]
    end

    Decision -->|Yes| DeployProxy
    DeployProxy --> Logic
    DeployProxy --> Proxy
    Proxy --> BatchConfig
    BatchConfig --> AddressBook
    AddressBook --> GTM[Omniforge launches storefront<br/>drops, partner placements]

    Decision -->|No — reuse existing| BatchMinter
    BatchConfig --> BatchMinter[KonduxBatchMinter
signature-gated issuance]

    BatchMinter --> MintFlow[Authorised mint flow<br/>allowlists, pricing, cadence]
    MintFlow --> Proxy
    MintFlow --> Authority[Authority vault orchestration<br/>treasury, partner, creator splits]
    Proxy --> Collectors[Collector wallets
receive dynamic kNFTs]
    Authority --> Treasury[Programmed disbursements<br/>royalty & revenue wallets]

    GDN --> Experience[Interactive experience layer<br/>streamed inside Omniforge]
    Proxy -. programmable royalties,<br/>DNA upgrades, token utilities .- Offering
    BatchMinter -. drop tooling,<br/>retail & enterprise integrations .- Offering
    GTM --> Analytics[Unified analytics & reporting<br/>engagement, primary/secondary flow]
    Analytics --> CreatorOps[Creator success team<br/>iterates future drops]
```

## Notes

- **Unified ingestion → commerce → delivery**: Omniforge packages creator assets, optimises them with NVIDIA GDN for real-time streaming, and aligns commercial terms before any onchain steps, ensuring the deployment mirrors the business blueprint.
- **Scalable Kondux architecture**: A single `KonduxImplementation` logic contract underpins every collection. When a creator needs a bespoke line, the platform spins up an ERC1967 proxy, initialises it with tier rules, and hands its address to `KonduxBatchMinter` via the new `setKNFT` hook.
- **Enterprise-grade drop controls**: `KonduxBatchMinter` orchestrates signature-gated mints (allowlists, partner allocations, timed releases) while enforcing economic guardrails—supply, pricing, DNA gating—defined in the Omniforge offering layer.
- **Automated finance and compliance**: Proceeds route through the `Authority` vault, executing royalty waterfalls and partner splits without manual intervention. Treasury events are logged in the Omniforge inventory ledger for audit, BI, and downstream payouts.
- **Actionable intelligence loop**: Every collection entry feeds omnichannel analytics so business development and creator success teams can optimise future drops, sponsorships, and live activations.
