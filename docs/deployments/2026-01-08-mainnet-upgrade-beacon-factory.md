# Mainnet Deployment Summary

## Deployment Status: ✅ SUCCESS

**Chain:** Ethereum Mainnet (Chain ID: 1)  
**Deployer:** `0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2`  
**Date:** January 8, 2026  
**Script:** `scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol`

---

## 📋 Deployed Contract Addresses

| Contract                       | Address                                      | Etherscan                                                                                 | Verified             |
| ------------------------------ | -------------------------------------------- | ----------------------------------------------------------------------------------------- | -------------------- |
| **KonduxImplementation** (new) | `0x426e0Bdff21Be7653eF2d43300Edd01E874a8BF0` | [View](https://etherscan.io/address/0x426e0Bdff21Be7653eF2d43300Edd01E874a8BF0#code)       | ✅                   |
| **KonduxBeaconFactory** (new)  | `0x0855A3063326623C22E62A376cC9e1715e6Da9A9` | [View](https://etherscan.io/address/0x0855A3063326623C22E62A376cC9e1715e6Da9A9#code)       | ⚠️ Bytecode mismatch |
| **Kondux Omniforge** (Clone)   | `0xaA030Da0C99726F83E9959b450482Fb00216C26D` | [View](https://etherscan.io/address/0xaA030Da0C99726F83E9959b450482Fb00216C26D)            | Proxy                |
| **KonduxRoyaltySplitter**      | `0xed860B54E8EeeF00A5EFe8B18120Aa1A35546666` | [View](https://etherscan.io/address/0xed860B54E8EeeF00A5EFe8B18120Aa1A35546666#code)       | ✅                   |
| **KonduxBatchMinter**          | `0x9b20eC629D3B530F036D7F25523673E8fE5989E3` | [View](https://etherscan.io/address/0x9b20eC629D3B530F036D7F25523673E8fE5989E3#code)       | ✅                   |

### Upgraded Contracts

| Contract                     | Address                                      | Etherscan                                                                            |
| ---------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Old Beacon** (upgraded)    | `0x21D1a52A17a1Df346Dd223Ef89D0e362Ee64b219` | [View](https://etherscan.io/address/0x21D1a52A17a1Df346Dd223Ef89D0e362Ee64b219)       |
| **Old Factory** (deprecated) | `0xa265a01205f304F2652277AaC924AB56D2e0Cf77` | [View](https://etherscan.io/address/0xa265a01205f304F2652277AaC924AB56D2e0Cf77)       |

---

## ✅ On-Chain Verification Results

### Clone Contract (Kondux Omniforge)

| Parameter               | Value                                                                                                                              | Status |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Name                    | `"Kondux Omniforge"`                                                                                                               | ✅     |
| Symbol                  | `"CRTR"`                                                                                                                           | ✅     |
| Max Supply              | `100,000`                                                                                                                          | ✅     |
| Base URI                | `https://toixbmwexblvs2o2rnl3kk63oi0hmvtm.lambda-url.us-east-1.on.aws/api/v1/metadata/0xaA030Da0C99726F83E9959b450482Fb00216C26D/` | ✅     |
| Royalty Splitter        | `0xed860B54E8EeeF00A5EFe8B18120Aa1A35546666`                                                                                       | ✅     |
| `royaltyInfo(1, 10000)` | Returns splitter + 1000 (10%)                                                                                                      | ✅     |

### Splitter Configuration

| Parameter           | Value                                        | Status |
| ------------------- | -------------------------------------------- | ------ |
| Collection          | `0xaA030Da0C99726F83E9959b450482Fb00216C26D` | ✅     |
| Manufacturer Cut    | 500 BP (5%)                                  | ✅     |
| Partner Cut         | 0 BP                                         | ✅     |
| Creator Cut         | 500 BP (5%)                                  | ✅     |
| Manufacturer Wallet | `0x3493c35A1890A758F21D74B757F051702f1dE82D` | ✅     |
| Creator Wallet      | `0x3493c35A1890A758F21D74B757F051702f1dE82D` | ✅     |

### Beacon Upgrade Verification

| Parameter                 | Value                                        | Status      |
| ------------------------- | -------------------------------------------- | ----------- |
| Old Beacon Implementation | `0x426e0Bdff21Be7653eF2d43300Edd01E874a8BF0` | ✅ UPGRADED |

### Transfer Validator Security (Limit Break V3)

| Parameter         | Value                                        | Status |
| ----------------- | -------------------------------------------- | ------ |
| Security Level    | 4 (Whitelisted operators only)               | ✅     |
| Whitelist ID      | 16 (OpenSea-compatible)                      | ✅     |
| Validator Address | `0x721C008fdff27BF06E7E123956E2Fe03B63342e3` | ✅     |

### Role Assignments

| Role            | Holder                        | Contract | Status |
| --------------- | ----------------------------- | -------- | ------ |
| MINTER_ROLE     | BatchMinter (`0x9b20eC...`)   | Clone    | ✅     |
| MINTER_ROLE     | Admin (`0x41BC231d...`)       | Clone    | ✅     |
| COLLECTION_ROLE | Clone (`0xaA030Da...`)        | Splitter | ✅     |

### BatchMinter & Factory

| Parameter                 | Value                                        | Status |
| ------------------------- | -------------------------------------------- | ------ |
| BatchMinter Target        | `0xaA030Da0C99726F83E9959b450482Fb00216C26D` | ✅     |
| BatchMinter Paused        | `false`                                      | ✅     |
| Factory Public Deployment | `false`                                      | ✅     |

---

## ⚠️ Notes

1. **Factory Verification Failed** - The `KonduxBeaconFactory` failed Etherscan verification due to via-ir bytecode mismatch. This is a known issue with Foundry's via-ir compilation. The contract is deployed and functional; you can verify manually via Etherscan's UI by uploading the flattened source with Standard JSON input.

2. **Existing Clones Continue Working** - The beacon upgrade means all existing clones deployed from the old factory now use the new implementation.

3. **Old Factory Deprecated** - The old factory at `0xa265a01205f304F2652277AaC924AB56D2e0Cf77` has the wrong function signatures and should no longer be used.

---

## Configuration Applied

| Setting                 | Value                                                          |
| ----------------------- | -------------------------------------------------------------- |
| Transfer Validator      | `0x721C008fdff27BF06E7E123956E2Fe03B63342e3` (Limit Break V3)  |
| Security Level          | 4 (Whitelisted operators only)                                 |
| Operator Whitelist ID   | 16                                                             |
| Total Royalty           | 10% (1000 BP) via splitter                                     |
| Manufacturer Cut        | 5% (500 BP)                                                    |
| Partner Cut             | 0%                                                             |
| Creator Cut             | 5% (500 BP)                                                    |

---

## Next Steps

1. ✅ Contracts deployed and verified (except factory - manual verification needed)
2. Update frontend/backend to use new factory: `0x0855A3063326623C22E62A376cC9e1715e6Da9A9`
3. Old factory is now deprecated (wrong function signatures)
4. Existing clones continue working (upgraded via beacon)
