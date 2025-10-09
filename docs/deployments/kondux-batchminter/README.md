# Kondux Batch Minter Deployment Playbook

This guide explains how to deploy a fresh `KonduxImplementation` + `KonduxBatchMinter` pair on Sepolia, a local mainnet fork, or Ethereum mainnet using the Forge script that now ships with this repository.

## Prerequisites

- Install the [Foundry toolchain](https://book.getfoundry.sh/getting-started/installation) and make sure `forge` is on your `PATH`.
- Populate `.env` with the signer keys used by the script:
  - `DEPLOYER_PK` – private key used for Sepolia deployments.
  - `PROD_DEPLOYER_PK` – private key used for mainnet or mainnet-fork smoke tests.
  - Optional helpers:
    - `USER_ADDRESS` – fallback admin for Sepolia (defaults to the address baked into the script).
    - `VERIFY` – set to `1` to enable automatic Etherscan verification.
    - `ETHERSCAN_API_KEY` – required when `VERIFY=1`.
- Export RPC endpoints for the networks you target (for example `SEPOLIA_RPC_URL`, `MAINNET_RPC_URL`, or the URL of your local fork) and pass them to `forge script` via `--rpc-url`.
- When running with `VERIFY=1`, enable FFI so the script can call `forge verify-contract` by passing `--ffi` (or setting the environment variable `FOUNDRY_FFI=1`).

Before broadcasting transactions it’s a good idea to run a dry simulation:

```pwsh
forge build
```

## Script entry point

The deployment logic lives in the Forge script:

```
script/DeployKonduxBatchMinter.s.sol
```

`DeployKonduxBatchMinterScript` performs the following high-level steps:

1. Loads a per-network configuration based on the connected chain ID.
2. Selects the correct broadcaster key (`DEPLOYER_PK` for Sepolia, `PROD_DEPLOYER_PK` otherwise) and tops it up on forked networks.
3. Reuses or creates the WETH/KNDX Uniswap V2 pair when required.
4. Deploys `KonduxImplementation`, initializes it, and grants `MINTER_ROLE` to the batch minter plus any configured operators.
5. Deploys `KonduxBatchMinter`, wires it to the shared `Authority`, and grants `BATCH_MINTER_ROLE` to the recipients listed in the config.
6. Applies post-setup actions (base URI, partner wallet, free-mint toggle) so the collection is usable immediately.
7. Hands off admin rights to the configured multisig, optionally revoking the deployer.
8. Appends an object to `docs/deployments/kondux-batchminter/address-book.json` with metadata about the run.
9. Optionally triggers `forge verify-contract` for both deployments when `VERIFY=1`.

## Running the script

> **Tip:** omit `--broadcast` to simulate the run against the target RPC without sending transactions.

### Sepolia (testnet)

```pwsh
forge script script/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript `
  --rpc-url $Env:SEPOLIA_RPC_URL `
  --broadcast `
  --ffi
```

- Uses the network configuration baked into `DeployKonduxBatchMinterScript` (creates the WETH/KNDX pair if missing).
- Grants admin and minter roles to `USER_ADDRESS` (or the hard-coded fallback) so you can immediately test mint flows.
- Include `--slow` if your RPC provider enforces strict rate limits.

### Local mainnet fork (smoke test)

1. Start an Anvil or Hardhat fork of Ethereum mainnet (`chainId` 31337).
2. In a separate shell, broadcast the deployment to the fork:

```pwsh
forge script script/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript `
  --rpc-url http://127.0.0.1:8545 `
  --broadcast `
  --ffi
```

- The script tops up the deployer with 1,000 ETH on forked networks to keep the rehearsal self-contained.
- The deployer retains admin rights on the fork for quicker debugging.

### Ethereum mainnet

```pwsh
forge script script/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript `
  --rpc-url $Env:MAINNET_RPC_URL `
  --broadcast `
  --ffi
```

- Requires `PROD_DEPLOYER_PK` to control the production multisig or hot wallet.
- Set `VERIFY=1` (and provide `ETHERSCAN_API_KEY`) to let the script submit verification requests after deployment.
- The deployer’s admin rights are revoked automatically once setup is complete.

## Address book entries

Each successful run appends an entry to `docs/deployments/kondux-batchminter/address-book.json` similar to:

```json
{
  "version": "1696774496-19123456",
  "chainId": 11155111,
  "konduxImplementation": "0x…",
  "konduxBatchMinter": "0x…",
  "konduxName": "Kondux kNFT (Sepolia)",
  "konduxSymbol": "kNFTs",
  "authority": "0x…",
  "admin": "0x…",
  "treasury": "0x…",
  "foundersPass": "0x…",
  "paymentToken": "0x…",
  "weth": "0x…",
  "uniswapPair": "0x…",
  "uniswapRouter": "0x…",
  "notes": "Deployer:0x…"
}
```

Treat this file as the single source of truth for deployment metadata, verifications, and release documentation. Commit the updated JSON after every broadcast to preserve the historical trail.

## Post-deployment configuration

The script leaves each fresh deployment mint-ready:

- **Base URI** – set to the value from the per-network config (only updated when it differs on chain).
- **Partner wallet** – points royalty distributions at the configured partner or treasury address.
- **Free mint toggle** – applies the requested policy (disabled by default in production configs).

Modify the config inside `DeployKonduxBatchMinterScript` before running if you need different metadata hosts or wallet wiring.

## Verification helpers

When `VERIFY=1` and `ETHERSCAN_API_KEY` are present, the script runs `forge verify-contract` for both deployments via FFI. The console output reports whether verification was submitted, skipped, or failed. If you prefer to verify manually, use the commands printed at the end of the run or adapt the template below:

```pwsh
forge verify-contract --chain-id <chainId> --num-of-optimizations 800 <address> \
  contracts/KonduxImplementation.sol:KonduxImplementation $Env:ETHERSCAN_API_KEY

forge verify-contract --chain-id <chainId> --num-of-optimizations 800 --constructor-args <calldata> <address> \
  contracts/KonduxBatchMinter.sol:KonduxBatchMinter $Env:ETHERSCAN_API_KEY
```
