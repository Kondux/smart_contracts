# Kondux kNFT Factory

This repository contains the **kNFTFactory** contract, designed to **deploy new** [Kondux kNFT](../../contracts/Kondux_NFT.sol) contracts. It provides additional functionality like optional ETH fees for contract creation, a whitelist mechanism for fee exemptions, and administrative controls over who can deploy new Kondux NFTs.

## Table of Contents

- [Kondux kNFT Factory](#kondux-knft-factory)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Key Features](#key-features)
  - [Factory Roles](#factory-roles)
  - [Deployment and Setup](#deployment-and-setup)
  - [Factory Logic in Detail](#factory-logic-in-detail)
    - [createKondux](#createkondux)
    - [Fee and Whitelist Logic](#fee-and-whitelist-logic)
      - [Example](#example)
    - [Restricting Creation](#restricting-creation)
  - [Configuration and Administration](#configuration-and-administration)
    - [Assigning Roles](#assigning-roles)
  - [Interacting via Node.js \& Ethers.js](#interacting-via-nodejs--ethersjs)
    - [1) Instantiate Factory](#1-instantiate-factory)
    - [2) Create a Kondux NFT](#2-create-a-kondux-nft)
    - [3) Toggle and Configure Factory](#3-toggle-and-configure-factory)
  - [Events](#events)

---

## Overview

The **kNFTFactory** contract is an administrative tool that **deploys new Kondux NFTs** (kNFT).  
Each newly deployed NFT:
- is fully configured with references to `WETH`, `KNDX`, a **Founder’s Pass** contract, a **treasury** address, etc.
- grants admin/minting/DNA-modification roles to the deployer (the caller of `createKondux`).
- automatically revokes the factory’s own roles on the new contract, ensuring the factory has **no** ongoing control.

Moreover, the factory can:
- Optionally charge an **ETH creation fee** for each new kNFT, which goes to a vault address managed by an **Authority** contract.
- Restrict creation so only **factory admins** can call `createKondux`.
- Maintain a **freeCreators** whitelist who don’t pay the fee even if fees are enabled.
- Provide a **default royalty** setting for newly deployed kNFTs (informational for ERC2981, but the actual on-chain royalty is enforced by the Kondux contract logic).

---

## Key Features

1. **Deploys new Kondux (kNFT) contracts**:
   - Automatically sets up the appropriate addresses for liquidity, WETH, KNDX, founder pass, etc.
2. **Optional ETH fee**:
   - If `isFeeEnabled` is `true`, anyone who calls `createKondux` must pay `creationFee` in ETH (unless whitelisted).
   - Forwarded to `authority.vault()`.
3. **Restrict creation**:
   - `isRestricted` can limit deployment to only addresses with `FACTORY_ADMIN_ROLE`.
4. **Default Royalty Fee** (ERC2981):
   - `defaultRoyaltyFee` is stored in the factory and can be used as an informational or reference point for newly created NFTs.
5. **Authority Contract Integration**:
   - The `authority` contract manages a `vault()` address. The factory uses that for fee collection.

---

## Factory Roles

- **DEFAULT_ADMIN_ROLE** (inherited from AccessControl):
  - Can grant/revoke the `FACTORY_ADMIN_ROLE`.
  - Full control over the factory.
- **FACTORY_ADMIN_ROLE**:
  - Can configure the factory (fees, restrictions, addresses).
  - Can call `createKondux` if `isRestricted` is true.
  - Has permission to set up the environment for the newly deployed NFTs (optionally).
  
Anyone can potentially call `createKondux` if:
- `isFactoryActive` is `true`; and
- `isRestricted` is `false`; or
- `msg.sender` has `FACTORY_ADMIN_ROLE` (when `isRestricted` is `true`).

---

## Deployment and Setup

1. **Install Dependencies** (same as the main project)
   ```bash
   npm install
   ```
2. **Compile**  
   ```bash
   npx hardhat compile
   ```
3. **Deploy** (example Hardhat script)
   ```js
   // scripts/deployFactory.js
   const hre = require('hardhat');

   async function main() {
     const kNFTFactory = await hre.ethers.getContractFactory("kNFTFactory");
     // Provide the address of your Authority contract
     const authorityAddr = "0xAuthorityAddress...";
     
     const factory = await kNFTFactory.deploy(authorityAddr);
     await factory.deployed();

     console.log("kNFTFactory deployed to:", factory.address);
   }

   main().catch((error) => {
     console.error(error);
     process.exitCode = 1;
   });
   ```
4. **Configure**:
   - Use `setUniswapV2Router`, `setWETH`, `setKNDX`, `setFoundersPass`, etc. to finalize references.
   - Optionally set `creationFee`, `isFeeEnabled`, etc.

---

## Factory Logic in Detail

### createKondux

The primary function:

```solidity
function createKondux(string memory name, string memory symbol)
  external
  payable
  restrictedOrAnyone
  returns (address)
{
  // 1) If fee is enabled & caller not in freeCreators => require msg.value >= creationFee
  // 2) Deploy a new Kondux contract
  // 3) Grant roles to msg.sender
  // 4) Revoke roles from the factory
  // 5) Emit kNFTDeployed event
}
```

**Key Steps**:

1. **Fee Check**:  
   - If `isFeeEnabled` = `true` and `freeCreators[msg.sender]` = `false`, require `msg.value >= creationFee`.
   - ETH is immediately forwarded to `authority.vault()`.
2. **Deployment**:  
   Instantiates a **new Kondux** NFT contract using the stored addresses (`WETH`, `KNDX`, `foundersPass`, etc.) and `authority.vault()` as the treasury.
3. **Roles**:
   - Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `DNA_MODIFIER_ROLE` on the new NFT to `msg.sender`.
   - Revokes these roles from the factory contract itself.
4. **Emits** `kNFTDeployed(newContractAddr, msg.sender)`.

---

### Fee and Whitelist Logic

- `isFeeEnabled`: If `false`, no one pays a fee (the call reverts if any ETH is sent).
- `creationFee`: The amount (in wei) required if fees are enabled.
- `freeCreators[addr]`: If `true`, that address is exempt from paying fees even when `isFeeEnabled` is `true`.

#### Example
- If `creationFee = 0.05 ETH`, and `isFeeEnabled = true`, then any caller **not** in `freeCreators` must send `0.05 ETH` (or more) to successfully create a new kNFT.

---

### Restricting Creation

- If `isRestricted = true`, **only** addresses with `FACTORY_ADMIN_ROLE` can call `createKondux`.
- If `isRestricted = false`, **anyone** can call it (assuming the factory is also `isFactoryActive = true`).

---

## Configuration and Administration

| Variable / Function                                  | Description                                                                                      |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `isFactoryActive` (set via `setFactoryActive`)        | Toggles overall factory on/off. If `false`, `createKondux` reverts.                              |
| `isFeeEnabled` (set via `setFeeEnabled`)             | If `true`, enforces an ETH creation fee unless the caller is whitelisted.                        |
| `creationFee` (set via `setCreationFee`)             | The required fee in wei if `isFeeEnabled` is `true`.                                            |
| `isRestricted` (set via `setRestricted`)             | If `true`, `createKondux` can only be called by addresses with `FACTORY_ADMIN_ROLE`.             |
| `freeCreators[addr]` (set via `setFreeCreator`)      | If `true`, `addr` is exempt from paying creation fees.                                          |
| `defaultRoyaltyFee` (set via `setDefaultRoyaltyFee`) | An informational default royalty for newly deployed kNFT.                                       |
| `authority` (set via `setAuthority`)                 | Points to an **Authority** contract that exposes `vault()`. That vault receives ETH fees.       |
| `uniswapV2Router` (set via `setUniswapV2Router`)     | Sets the Uniswap V2 router address to be passed along to new kNFTs.                              |
| `WETH` (set via `setWETH`)                           | The WETH token address.                                                                          |
| `KNDX` (set via `setKNDX`)                           | The KNDX token address.                                                                          |
| `foundersPass` (set via `setFoundersPass`)           | The Founder’s Pass (ERC721) contract address.                                                   |

All admin/configuration functions require `FACTORY_ADMIN_ROLE`.

---

### Assigning Roles

To grant or revoke roles on the factory itself:
```solidity
// from an account with DEFAULT_ADMIN_ROLE
factory.grantRole(factory.FACTORY_ADMIN_ROLE(), adminAddress);
factory.revokeRole(factory.FACTORY_ADMIN_ROLE(), someAddress);
```

---

## Interacting via Node.js & Ethers.js

Below is an example setup for interacting with the deployed **kNFTFactory** contract. We assume you have:

- A project with `npm install ethers dotenv`.
- A `.env` with your private key and JSON-RPC endpoint.

### 1) Instantiate Factory

```js
require('dotenv').config();
const { ethers } = require('ethers');
const factoryAbi = require('./kNFTFactoryABI.json'); // The ABI of the kNFTFactory

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  // Deployed factory address
  const factoryAddress = "0xFactoryAddress...";
  const factory = new ethers.Contract(factoryAddress, factoryAbi, signer);

  // Now you can call factory functions!
}

main();
```

---

### 2) Create a Kondux NFT

```js
async function createNewKondux(factory, name, symbol, feeInWei) {
  // If the factory is restricted, ensure your signer has FACTORY_ADMIN_ROLE
  // If the factory has a creation fee, you may need to pass `value: feeInWei`

  const tx = await factory.createKondux(
    name,
    symbol,
    {
      value: feeInWei // pass 0 if no fee is required
    }
  );
  const receipt = await tx.wait();

  // The event kNFTDeployed(address newNFT, address admin) returns the new NFT address
  const event = receipt.events.find(e => e.event === "kNFTDeployed");
  const newNftAddress = event.args[0]; 
  console.log("Deployed new Kondux NFT at address:", newNftAddress);

  // Now you can instantiate the new NFT contract if needed:
  // const newNFT = new ethers.Contract(newNftAddress, KonduxABI, factory.signer);
}

await createNewKondux(factory, "MyKonduxToken", "MKDX", ethers.utils.parseEther("0.05"));
```

- If `isFeeEnabled = false`, set `value: 0`.
- If `isFeeEnabled = true` but you’re on the **freeCreators** list, also `value: 0` is fine.

---

### 3) Toggle and Configure Factory

```js
async function configureFactory(factory) {
  // Must have FACTORY_ADMIN_ROLE
  let tx = await factory.setFactoryActive(true);
  await tx.wait();

  tx = await factory.setFeeEnabled(true);
  await tx.wait();

  tx = await factory.setCreationFee(ethers.utils.parseEther("0.05"));
  await tx.wait();

  tx = await factory.setRestricted(true);
  await tx.wait();

  // Whitelist an address for free creation
  tx = await factory.setFreeCreator("0xSomeAddress", true);
  await tx.wait();

  // Update references
  tx = await factory.setWETH("0xWETHAddress");
  await tx.wait();

  tx = await factory.setKNDX("0xKNDXAddress");
  await tx.wait();

  // etc.
}
```

---

## Events

- **`kNFTDeployed(address newkNFT, address admin)`**: Emitted upon deploying a new Kondux NFT contract.
- **`FactoryToggled(bool isFactoryActive, bool isFeeEnabled, bool isRestricted)`**: Whenever the factory toggles active state, fee, or restriction.
- **`FactoryFeeUpdated(uint256 newFee)`**: Emitted when the creation fee changes.
- **`FactoryRoyaltyFeeUpdated(uint96 newFee)`**: Emitted when `defaultRoyaltyFee` changes.
- **`FreeCreatorUpdated(address creator, bool isFree)`**: When an address is added or removed from the fee whitelist.
