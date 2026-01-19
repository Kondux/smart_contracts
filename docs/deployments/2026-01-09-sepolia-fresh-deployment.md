# Sepolia Fresh Deployment - January 9, 2026

## Deployment Summary

Fresh deployment of Kondux NFT infrastructure on Sepolia testnet.

**Network:** Sepolia (chainId: 11155111)
**Deployer:** `0x9767a2B120614F526e923DAAF89843EC7C2292d7`
**Date:** 2026-01-09
**Gas Price:** 1 gwei

---

## Deployed Contracts

| Contract | Address | Verified |
|----------|---------|----------|
| KonduxImplementation | [`0x2cd84bf963A712D65cd8596CFA220C635D608487`](https://sepolia.etherscan.io/address/0x2cd84bf963A712D65cd8596CFA220C635D608487) | ✅ |
| KonduxBeaconFactory | [`0x0481933A66264DE3e444508bFB2159E732420748`](https://sepolia.etherscan.io/address/0x0481933A66264DE3e444508bFB2159E732420748) | ❌ |
| UpgradeableBeacon | [`0x7478Befa1dC8D681e77bE9eE4a167996dfF3140a`](https://sepolia.etherscan.io/address/0x7478Befa1dC8D681e77bE9eE4a167996dfF3140a) | ✅ |
| KonduxRoyaltySplitter | [`0x96A0c58aae31a6E4aa492b98D3620be0AD3c2bEe`](https://sepolia.etherscan.io/address/0x96A0c58aae31a6E4aa492b98D3620be0AD3c2bEe) | ✅ |
| BeaconProxy (Clone) | [`0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c`](https://sepolia.etherscan.io/address/0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c) | ✅ |

> **Note:** KonduxBeaconFactory verification failed due to bytecode mismatch (likely EVM version: Prague vs Paris). Contract is functional.

---

## Test Clone Configuration

| Setting | Value |
|---------|-------|
| Name | Kondux Sepolia Test |
| Symbol | KSEP |
| Max Supply | 10,000 |
| Admin | `0x9767a2B120614F526e923DAAF89843EC7C2292d7` |
| Base URI | `https://toixbmwexblvs2o2rnl3kk63oi0hmvtm.lambda-url.us-east-1.on.aws/api/v1/metadata/0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c/` |

---

## Royalty Configuration

| Split | Percentage | Basis Points |
|-------|------------|--------------|
| **Total Royalty** | 10% | 1000 BP |
| Manufacturer | 5% | 500 BP |
| Partner | 0% | 0 BP |
| Creator | 5% | 500 BP |

**Manufacturer Wallet:** `0x9767a2B120614F526e923DAAF89843EC7C2292d7`
**Creator Wallet (Default):** `0x9767a2B120614F526e923DAAF89843EC7C2292d7`

---

## Roles Granted

### On Factory (`0x0481933A66264DE3e444508bFB2159E732420748`)

| Role | Address |
|------|---------|
| DEFAULT_ADMIN_ROLE | `0x9767a2B120614F526e923DAAF89843EC7C2292d7` |
| FEE_ADMIN_ROLE | `0x9767a2B120614F526e923DAAF89843EC7C2292d7` |
| CLONE_DEPLOYER_ROLE | `0x9767a2B120614F526e923DAAF89843EC7C2292d7` |

### On Clone (`0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c`)

| Role | Address |
|------|---------|
| DEFAULT_ADMIN_ROLE | `0x9767a2B120614F526e923DAAF89843EC7C2292d7` |
| MINTER_ROLE | `0x9767a2B120614F526e923DAAF89843EC7C2292d7` |

### On Splitter (`0x96A0c58aae31a6E4aa492b98D3620be0AD3c2bEe`)

| Role | Address |
|------|---------|
| ADMIN_ROLE | Factory (`0x0481933A66264DE3e444508bFB2159E732420748`) |
| COLLECTION_ROLE | Clone (`0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c`) |

---

## Verification Status

- ✅ `royaltyInfo()` correctly returns splitter address
- ✅ Clone has COLLECTION_ROLE on splitter
- ✅ Splitter collection address matches clone
- ✅ Transfer Validator configured (Whitelist ID: 23)
- ✅ OpenSea Conduit added to whitelist
- ⚠️ BatchMinter not deployed (no Authority contract set)

## Transfer Validator Configuration

**Transfer Validator:** `0x721C008fdff27BF06E7E123956E2Fe03B63342e3` (same as mainnet)
**Security Level:** 4 (Operator Whitelist)
**Whitelist ID:** 23 ("Kondux Default Whitelist")

**Whitelisted Operators:**
- Seaport 1.6: `0x0000000000000068F116a894984e2DB1123eB395`
- OpenSea Conduit: `0x1E0049783F008A0085193E00003D00cd54003c71`

**Transactions:**
- Set Security Policy: [`0xab9b77e39eb4ac80735da0fcb299dcff6927c61bc307dfebb2e906ec424de074`](https://sepolia.etherscan.io/tx/0xab9b77e39eb4ac80735da0fcb299dcff6927c61bc307dfebb2e906ec424de074)
- Add Conduit: [`0x59e227b488cf857909fbbdaccd80037a0f9351e20a72ad22896aa37f2f78e2e5`](https://sepolia.etherscan.io/tx/0x59e227b488cf857909fbbdaccd80037a0f9351e20a72ad22896aa37f2f78e2e5)

---

## Testing Commands

### Mint a Token

```bash
wsl -e bash -c "source /mnt/d/git/smart_contracts/.env && ~/.foundry/bin/cast send 0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c 'safeMint(address,uint256)' 0x9767a2B120614F526e923DAAF89843EC7C2292d7 12345 --rpc-url \$SEPOLIA_RPC_URL --private-key \$DEPLOYER_PK"
```

### Query Token Owner

```bash
wsl -e bash -c "source /mnt/d/git/smart_contracts/.env && ~/.foundry/bin/cast call 0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c 'ownerOf(uint256)' 0 --rpc-url \$SEPOLIA_RPC_URL"
```

### Query Royalty Info

```bash
wsl -e bash -c "source /mnt/d/git/smart_contracts/.env && ~/.foundry/bin/cast call 0x4ddbBCb93cDcaea7A6eea00c69707C68a694226c 'royaltyInfo(uint256,uint256)' 0 1000000000000000000 --rpc-url \$SEPOLIA_RPC_URL"
```

### Deploy Another Clone

```bash
wsl -e bash -c "source /mnt/d/git/smart_contracts/.env && ~/.foundry/bin/cast send 0x0481933A66264DE3e444508bFB2159E732420748 'deployCloneWithSplitter(string,string,uint256,address,bool,address,uint96,uint96,uint96,address)' 'My NFT' 'MNFT' 1000 0x9767a2B120614F526e923DAAF89843EC7C2292d7 true 0x0000000000000000000000000000000000000000 500 0 500 0x9767a2B120614F526e923DAAF89843EC7C2292d7 --rpc-url \$SEPOLIA_RPC_URL --private-key \$DEPLOYER_PK"
```

---

## Deployment Script

**Script:** `scripts/solidity/deploy/DeploySepoliaFresh.s.sol`

**Command Used:**
```bash
DRY_RUN=false forge script scripts/solidity/deploy/DeploySepoliaFresh.s.sol \
  --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --with-gas-price 1000000000 -vvv
```

---

## Transaction Log

Transactions saved to: `broadcast/DeploySepoliaFresh.s.sol/11155111/run-latest.json`
