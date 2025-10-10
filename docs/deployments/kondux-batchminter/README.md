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

## Python orchestration CLI

Most operators should drive deployments through the helper script at `scripts/manage_batch_minter.py`. It wraps the Forge script with network presets, WSL-aware binary discovery, Alchemy RPC selection, and post-run reporting.

### Installation and environment

- Ensure the prerequisites above are met (Foundry installed, `.env` populated).
- Optional overrides:
  - `FORGE_BIN` / `ANVIL_BIN` can point to custom executable paths when they are not on `PATH`.
  - `ALCHEMY_*` keys and `ETHERSCAN_API_KEY` may also be exported directly in the shell.
- The helper automatically resolves `forge`/`anvil` through typical Windows install locations, `.cargo/bin`, or WSL (`wsl bash -lc ...`), so PowerShell functions and wrappers are supported without extra configuration.

### Common command patterns

```pwsh
python scripts/manage_batch_minter.py deploy --network sepolia --show-defaults

python scripts/manage_batch_minter.py deploy --network mainnet --skip-verify --slow

python scripts/manage_batch_minter.py smoke --port 8545 --skip-verify

python scripts/manage_batch_minter.py verify --network sepolia
```

- Use `--show-defaults` with any command to print the baked-in configuration before it runs.
- `--dry-run` simulates Sepolia/mainnet deployments without `--broadcast`; `--no-broadcast` suppresses broadcasting even when not in dry-run mode.
- The smoke command spins up an Anvil mainnet fork, waits for it to boot (tunable via `--startup-delay`), and then executes the Forge script against `http://127.0.0.1:<port>`.
- Extra arguments after `smoke --anvil-args` are forwarded directly to Anvil (for example `--anvil-args --fork-block-number 19000000`).
- Successful runs append to `docs/deployments/kondux-batchminter/address-book.json` and the helper echoes the latest entry for quick verification.
- The `verify` subcommand replays Etherscan verification for the latest deployment on the requested network and records the outcome back into the address book.

### RPC and verification behaviour

- When `--rpc-url` is omitted, the helper selects an Alchemy endpoint using the per-network key precedence (`ALCHEMY_<NETWORK>_API_KEY` then `ALCHEMY_API_KEY`).
- The deploy and smoke commands set `FOUNDRY_FFI=1` automatically so verification hooks can run.
- `--skip-verify` forces `VERIFY=0` during the run, while the default honours `VERIFY` from the environment, enabling Etherscan submissions when the key is present.

### Environment validations

- The helper normalises private keys so values with or without the `0x` prefix are accepted; malformed keys (non-hex or wrong length) still trigger a friendly error before Forge runs.
- If required binaries cannot be found, the helper exits with a message describing how to install Foundry or override the path via environment variables.

## Script entry point

The deployment logic lives in the Forge script:

```
script/DeployKonduxBatchMinter.s.sol
```

`DeployKonduxBatchMinterScript` performs the following high-level steps:

1. Loads a per-network configuration based on the connected chain ID.
2. Selects the correct broadcaster key (`DEPLOYER_PK` for Sepolia, `PROD_DEPLOYER_PK` otherwise) and tops it up on forked networks.
3. Reuses or creates the WETH/KNDX Uniswap V2 pair when required.
4. Deploys the upgradeable `KonduxImplementation` logic contract plus an `ERC1967Proxy`, initialising the proxy with the network-specific parameters (Uniswap pair, WETH, KNDX ERC‑20, founders pass, treasury, max supply) and logging both addresses.
5. Deploys `KonduxBatchMinter`, wires it to the shared `Authority`, and grants both `MINTER_ROLE` and `DNA_MODIFIER_ROLE` on `KonduxImplementation` plus `BATCH_MINTER_ROLE` on the batch minter to all configured recipients (including the batch minter contract itself).
6. Applies post-setup actions so the collection is usable immediately: synchronises the on-chain core addresses (pair, WETH, KNDX, founders pass, treasury), sets the base URI, partner wallet, and free-mint toggle when they differ on chain.
7. Hands off admin rights to the configured multisig, optionally revoking the deployer.
8. Appends an object to `docs/deployments/kondux-batchminter/address-book.json` with metadata about the run (including proxy + logic addresses and Uniswap pair).
9. Optionally triggers `forge verify-contract` for the logic contract and the batch minter when `VERIFY=1`.

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
  "konduxImplementationProxy": "0x…",
  "konduxImplementationLogic": "0x…",
  "konduxBatchMinter": "0x…",
  "konduxName": "Kondux kNFT (Sepolia)",
  "konduxSymbol": "kNFTs",
  "authority": "0x…",
  "admin": "0x…",
  "treasury": "0x…",
  "foundersPass": "0x…",
  "paymentToken": "0x…",
  "kndxToken": "0x…",
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
- **Core addresses** – re-applies the Uniswap pair, WETH, KNDX ERC‑20, founders pass, and treasury wiring if any of them drift from the baked-in config.

Modify the config inside `DeployKonduxBatchMinterScript` before running if you need different metadata hosts or wallet wiring.

## Existing contract setup helper

Already have the contracts deployed but need to re-run the wiring (roles, base URI, partner wallet, Uniswap/KNDX addresses)? Call the helper exposed by the Forge script:

```pwsh
forge script script/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript `
  --sig "setupExistingKondux(address,address)" 0xYourKonduxProxy 0xYourBatchMinter `
  --rpc-url $Env:SEPOLIA_RPC_URL `
  --broadcast `
  --ffi
```

- Uses the same per-network config loader as a fresh deployment, so ensure you point the script at the correct chain ID / RPC.
- Grants missing `MINTER_ROLE` and `DNA_MODIFIER_ROLE` permissions to the batch minter and any additional recipients defined in the config.
- Re-syncs the Uniswap pair, WETH, KNDX ERC‑20, founders pass, treasury, base URI, partner wallet, and free-mint toggle without redeploying the contracts.
- Hands off admin rights to the configured multisig/admin if they were removed and optionally revokes the broadcaster, keeping governance consistent.

Use this helper any time an on-chain admin tweaks the collection and you want to revert to the canonical configuration recorded in the script.

## Verification helpers

When `VERIFY=1` and `ETHERSCAN_API_KEY` are present, the script runs `forge verify-contract` for both deployments via FFI. The console output reports whether verification was submitted, skipped, or failed, and it also prints the exact (API-key-sanitised) commands that can be re-run manually. Each command now includes `--watch`, `--retries 12`, and `--delay 10` so Foundry waits for Etherscan to index the deployment instead of failing immediately.

In addition, the tooling now calls `forge verify-proxy` to register the ERC1967 proxy with Etherscan. This step links the proxy address to the Kondux implementation ABI so the "Read" and "Write" tabs light up for the proxy contract instead of only showing the fallback methods.

For environments where verification needs to happen later, run the Python helper:

```pwsh
python scripts/manage_batch_minter.py verify --network sepolia
```

The helper looks up the latest entry in the address book, runs the necessary `forge verify-contract` invocations (via Windows, native, or WSL `forge`), and caches the outcome under `verification.components`. Each component is tagged with the command used, the trimmed verifier response, and a success/failure flag. Re-running the command will refresh those fields.

All stored command strings mask sensitive values (e.g. the API key is persisted as `$ETHERSCAN_API_KEY`) so the address book remains safe to commit.

If you prefer to verify manually, use the commands printed at the end of the run or adapt the template below:
```json
{
  "version": "1696774496-19123456",
  "chainId": 11155111,
  "konduxImplementationProxy": "0x…",
  "konduxImplementationLogic": "0x…",
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
  "notes": "Deployer:0x…",
  "verification": {
    "status": "success",
    "lastRun": "2025-10-09T15:23:17Z",
    "components": {
      "konduxImplementationProxy": {
        "status": "success",
        "command": "forge verify-proxy ...",
        "output": "Proxy registered ...",
        "updatedAt": "2025-10-09T15:23:17Z"
      },
      "konduxImplementationLogic": {
        "status": "success",
        "command": "forge verify-contract ...",
        "output": "Verification submitted ...",
        "updatedAt": "2025-10-09T15:23:17Z"
      },
      "konduxBatchMinter": {
        "status": "success",
        "command": "forge verify-contract ...",
        "output": "Verification submitted ...",
        "updatedAt": "2025-10-09T15:23:17Z"
      }
    }
  }
}
```

- `forge verify-contract --chain-id ... --etherscan-api-key ... --watch --retries 12 --delay 10 <proxy> contracts/KonduxImplementation.sol:KonduxImplementation`
- `forge verify-contract --chain-id ... --constructor-args <encodedArgs> --etherscan-api-key ... --watch --retries 12 --delay 10 <batchMinter> contracts/KonduxBatchMinter.sol:KonduxBatchMinter`
- `forge verify-proxy --chain-id ... --proxy-type oz-upgrades --etherscan-api-key ... --watch --retries 12 --delay 10 <proxy> <logic>`
