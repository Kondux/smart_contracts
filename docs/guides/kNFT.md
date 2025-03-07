# Kondux kNFT Contract

This repository contains the **Kondux kNFT** smart contract, an ERC721-compliant NFT with additional functionality for:
- **Enforced royalties (in KNDX tokens)**, pegged to a configurable ETH amount (default 0.001 ETH).
- Optional exemptions for **founder pass** holders and the **original minter** (royalty owner).
- An optional **1% treasury fee** on each royalty payment.
- A **DNA system** to store and manipulate 256-bit “genetic data” per token.

It is built on top of OpenZeppelin libraries and offers extended capabilities such as metadata updates (EIP-4906), enumerability, burnability, and configurable roles for minting and DNA modification.

## Table of Contents

- [Kondux kNFT Contract](#kondux-knft-contract)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [Why Kondux kNFT?](#why-kondux-knft)
  - [Key Features](#key-features)
  - [Roles](#roles)
  - [DNA System](#dna-system)
    - [Storing DNA](#storing-dna)
    - [Reading DNA](#reading-dna)
    - [Modifying DNA](#modifying-dna)
  - [Royalty System](#royalty-system)
    - [How It Works (Non-Technical)](#how-it-works-non-technical)
    - [How It Works (Technical)](#how-it-works-technical)
  - [Deployment and Setup](#deployment-and-setup)
  - [Interacting via Node.js \& Ethers.js](#interacting-via-nodejs--ethersjs)
    - [1) Instantiate Contract](#1-instantiate-contract)
    - [2) Mint an NFT (`safeMint`)](#2-mint-an-nft-safemint)
    - [3) Read Token DNA](#3-read-token-dna)
    - [4) Set Token DNA](#4-set-token-dna)
    - [5) Modify Part of Token DNA (`writeGen`)](#5-modify-part-of-token-dna-writegen)
    - [6) Set Token Royalties](#6-set-token-royalties)
  - [Administration Functions](#administration-functions)
    - [Toggling Features](#toggling-features)
    - [Assigning Roles](#assigning-roles)
    - [Updating Base URI](#updating-base-uri)
  - [Events](#events)

---

## Overview

**Kondux kNFT** is an ERC721-based NFT contract designed for projects that want strict on-chain enforcement of royalties using the KNDX token. While typical ERC721 tokens rely on off-chain marketplace enforcement of royalties, **Kondux kNFT** attempts to collect them directly on every transfer—unless you qualify for an exemption.

### Why Kondux kNFT?
1. **On-Chain Royalty Enforcement**: Royalties can’t be bypassed unless you are exempt (e.g., a founder pass holder).
2. **Token DNA**: Each NFT has a 256-bit “DNA” that can be read, written, and partially updated. This can power advanced NFT metadata or attributes.
3. **Fully Configurable**: Admin controls over:
   - royalty enforcement
   - founder pass & minter exemptions
   - treasury fee
   - free minting vs. restricted minting
4. **Royalty in KNDX, Pegged to ETH**: The contract reads on-chain liquidity (via a Uniswap V2 pair) to convert a fixed ETH amount into an equivalent KNDX amount, ensuring the royalty always tracks a stable ETH pegged rate.

---

## Key Features

- **Minting**:
  - `safeMint(address to, uint256 dna)`: Mints a new NFT to the specified address with the given `dna`.
  - Admins can toggle `freeMinting`. If set to `false`, only addresses with the `MINTER_ROLE` may mint.
- **DNA**:
  - Each token has a 256-bit unsigned integer storing its “DNA”.
  - DNA can be fully replaced or partially modified (byte ranges).
- **Royalties**:
  - By default, each token has a royalty of `0.001 ETH` (in KNDX).
  - Royalty amount is adjustable by the token’s royalty owner.
  - Optional 1% treasury fee can be toggled.
  - Exemptions for original minter (“royalty owner”) and founder pass holders.
- **EIP-4906** (Metadata Updates):
  - Allows off-chain tools (like NFT marketplaces) to refresh metadata automatically when `DnaChanged` or `DnaModified` events are emitted.

---

## Roles

- **DEFAULT_ADMIN_ROLE** (`admin`):
  - Can grant/revoke all other roles.
  - Can toggle global settings (royalty enforcement, treasury fee, founder pass exemption, etc.).
  - Can update base URI, emergency withdraw assets, etc.
- **MINTER_ROLE**:
  - Can mint new NFTs if `freeMinting` is `false`.
- **DNA_MODIFIER_ROLE**:
  - Can directly set or partially modify token DNA.

You can assign/revoke roles by calling `setRole(role, addr, enabled)`.

---

## DNA System

Each token has a `uint256` called `DNA`. This represents a 256-bit sequence that can be interpreted any way you like (e.g. trait encodings, random seeds, etc.).  
- **`indexDna[tokenId]`** holds the full DNA.
- **`readGen(tokenId, startIndex, endIndex)`** extracts a slice of bytes (big-endian).
- **`writeGen(tokenId, inputValue, startIndex, endIndex)`** modifies a slice of bytes (big-endian).

### Storing DNA
When you **mint** a token, you pass in a full `uint256` for `dna`. Internally, it gets stored in `indexDna[tokenId]`.

### Reading DNA
Use `getDna(tokenId)` to fetch the entire 256-bit integer.  
Or use `readGen(tokenId, startIndex, endIndex)` to fetch partial segments in bytes. For example:
```solidity
// Suppose token's DNA is 0xFFEE... in 256 bits.
// readGen(tokenId, 0, 2) could extract the top 2 bytes, for example.
```

### Modifying DNA
The **owner** is not necessarily allowed to change DNA. Only addresses with the `DNA_MODIFIER_ROLE` can:
- `setDna(tokenId, dna)`: replace the entire 256 bits
- `writeGen(tokenId, inputValue, startIndex, endIndex)`: partial updates in big-endian manner.

Both functions emit `DnaChanged` or `DnaModified`, triggering EIP-4906 metadata refresh events.

---

## Royalty System

### How It Works (Non-Technical)

1. **Royalty Payment on Transfer**  
   Whenever someone transfers (sends) an NFT from one address to another, the contract checks if that address owes a royalty.
   
2. **Who is Exempt?**  
   - The **original minter** of the NFT (if minted-owner exemption is enabled).
   - Anyone who holds a **founder pass** NFT (if founder pass exemption is enabled).
   If the sender is exempt, no royalty is collected.

3. **Royalty Amount**  
   By default, each kNFT charges **0.001 ETH** worth of KNDX for the transfer. The contract looks at the WETH-KNDX pool on Uniswap to find how many KNDX tokens equal 0.001 ETH at that moment.

4. **Paying the Royalty**  
   - The sender must pay that many KNDX tokens to the NFT’s royalty owner (usually the original minter).
   - Optionally, 1% of that payment goes to the Kondux treasury if the treasury fee is enabled.

5. **Adjusting the Royalty**  
   The royalty owner (the address that originally minted the token) can change the royalty from `0.001 ETH` to any other amount, or even zero (disabling royalties for that token).

This mechanism ensures that **each transfer** automatically checks for the royalty in KNDX. If the user hasn’t approved enough KNDX to be transferred on their behalf, the transfer will fail, enforcing that royalty is always paid.

### How It Works (Technical)

1. **On `_update(to, tokenId, auth)`** (i.e., transfer):
   - If `from != address(0)` and `to != address(0)` (meaning a non-mint, non-burn transfer):
     - Checks if `royaltyEnforcementEnabled` is `true`.
     - Calls `_enforceRoyalty(from, tokenId)`.
2. **`_enforceRoyalty(from, tokenId)`**:
   - Reads `royaltyETHWei[tokenId]`. E.g., `1e15` => 0.001 ETH.
   - Checks if `founderPassExemptEnabled` and `foundersPass.balanceOf(from) > 0`; or if `mintedOwnerExemptEnabled` and `from == royaltyOwnerOf[tokenId]`. If either is `true`, skip royalty.
   - Otherwise:
     - Convert that ETH amount to KNDX using `getKndxForEth(royaltyETHWei[tokenId])`.
     - If `treasuryFeeEnabled`, split (1% to treasury, 99% to royalty owner).
     - Transfer KNDX from `from` to `royaltyOwnerOf[tokenId]` and optionally to the `konduxTreasury`.
3. **Changing the Royalty**:  
   `setTokenRoyaltyEth(tokenId, ethAmountWei)` can be called by `royaltyOwnerOf[tokenId]`.  
   - If `ethAmountWei = 0`, no royalty is required going forward.

---

## Deployment and Setup

1. **Install Dependencies**  
   ```bash
   npm install
   ```
2. **Compile**  
   ```bash
   npx hardhat compile
   ```
3. **Deploy** (example Hardhat script)
   ```js
   // scripts/deploy.js
   const hre = require("hardhat");

   async function main() {
     const Kondux = await hre.ethers.getContractFactory("Kondux");
     const kNFT = await Kondux.deploy(
       "Kondux",             // _name
       "kNFT",               // _symbol
       "<UNISWAP_PAIR>",     // _uniswapV2Pair
       "<WETH_ADDRESS>",     // _weth
       "<KNDX_ADDRESS>",     // _kndx
       "<FOUNDERS_PASS>",    // _foundersPass
       "<KONDUX_TREASURY>"   // _treasury
     );
     await kNFT.deployed();
     console.log("Kondux kNFT deployed to:", kNFT.address);
   }

   main().catch((error) => {
     console.error(error);
     process.exitCode = 1;
   });
   ```
4. **Verify** (optional, on Etherscan)
   ```bash
   npx hardhat verify --network <network> <DEPLOYED_ADDRESS> "Kondux" "kNFT" "<UNISWAP_PAIR>" ...
   ```

---

## Interacting via Node.js & Ethers.js

Below is an example setup for interacting with the deployed contract. We assume you already have:
- A project configured with `npm install ethers dotenv`.
- A `.env` file containing your private key and a JSON-RPC endpoint (e.g., Infura).

### 1) Instantiate Contract

```js
require('dotenv').config();
const { ethers } = require('ethers');
const abi = require('./KonduxABI.json'); // Exported ABI of the Kondux contract

async function main() {
  // Provider
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

  // Signer
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  // Already deployed contract address
  const kNFTAddress = "0x1234..."; 

  // Create a contract instance
  const kNFT = new ethers.Contract(kNFTAddress, abi, signer);

  // Now you can call contract functions
}

main();
```

---

### 2) Mint an NFT (`safeMint`)

```js
async function safeMint(kNFT, to, dnaValue) {
  const tx = await kNFT.safeMint(to, dnaValue);
  const receipt = await tx.wait();
  console.log("Mint transaction:", receipt.transactionHash);

  // The tokenId is returned as an event or increment. 
  // Let’s assume you can parse it from the event logs:
  const transferEvent = receipt.events.find(e => e.event === 'Transfer');
  const tokenId = transferEvent.args.tokenId;
  console.log(`New token minted with ID: ${tokenId.toString()}`);
}
```

Usage:
```js
const dnaValue = ethers.BigNumber.from("0x1234567890ABCDEF..."); // 256-bit
await safeMint(kNFT, "0xabcd1234recipient...", dnaValue);
```

> **Note**: If `freeMinting = false`, you need to have `MINTER_ROLE`. Otherwise, the transaction will revert.

---

### 3) Read Token DNA

```js
async function readTokenDNA(kNFT, tokenId) {
  const dnaBigNumber = await kNFT.getDna(tokenId);
  console.log(`Token #${tokenId} DNA:`, dnaBigNumber.toHexString());
  
  // Read partial bytes
  // e.g. read the top 2 bytes, from index=0 to index=2
  const twoBytes = await kNFT.readGen(tokenId, 0, 2);
  console.log(`Top two bytes: ${ethers.BigNumber.from(twoBytes).toHexString()}`);
}

await readTokenDNA(kNFT, 0); // for tokenId=0
```

---

### 4) Set Token DNA

Requires `DNA_MODIFIER_ROLE`.

```js
async function setDna(kNFT, tokenId, newDna) {
  const tx = await kNFT.setDna(tokenId, newDna);
  const receipt = await tx.wait();
  console.log(`DNA for token #${tokenId} updated! Tx:`, receipt.transactionHash);
}

// example usage
const newDNA = ethers.BigNumber.from("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
await setDna(kNFT, 0, newDNA);
```

---

### 5) Modify Part of Token DNA (`writeGen`)

Also requires `DNA_MODIFIER_ROLE`.

```js
async function writeGenSegment(kNFT, tokenId, inputValue, startIndex, endIndex) {
  // inputValue = the partial data to set
  // startIndex, endIndex = byte range [startIndex, endIndex)
  const tx = await kNFT.writeGen(tokenId, inputValue, startIndex, endIndex);
  const receipt = await tx.wait();
  console.log(`DNA segment updated! Tx:`, receipt.transactionHash);
}

// Example: write 0xBEEF to bytes [0..2)
await writeGenSegment(
  kNFT, 
  0,              // tokenId
  "0xbeef",       // inputValue 
  0,              // start index
  2               // end index
);
```

---

### 6) Set Token Royalties

The address that originally **minted** the NFT becomes the `royaltyOwnerOf[tokenId]`. That address can set the token’s required ETH (in wei) for the royalty. `0` disables royalties.

```js
async function setTokenRoyalty(kNFT, tokenId, ethAmountWei) {
  // Only the royalty owner can call this
  const tx = await kNFT.setTokenRoyaltyEth(tokenId, ethAmountWei);
  const receipt = await tx.wait();
  console.log(`Royalty for token #${tokenId} updated to ${ethAmountWei.toString()} wei`);
}

// Example: set royalty to 0.002 ETH
// 0.002 ETH = 2e15 Wei
await setTokenRoyalty(kNFT, 123, ethers.BigNumber.from("2000000000000000"));
```

---

## Administration Functions

### Toggling Features

| Function                                 | Description                                                  |
| ---------------------------------------- | ------------------------------------------------------------ |
| `setRoyaltyEnforcement(bool _enabled)`   | Enable/disable on-chain royalty logic.                       |
| `setFounderPassExempt(bool _enabled)`    | Enable/disable founder pass holders exemption from royalties.|
| `setMintedOwnerExempt(bool _enabled)`    | Enable/disable original minter exemption.                    |
| `setTreasuryFeeEnabled(bool _enabled)`   | Enable/disable 1% cut to the Kondux treasury on royalty.     |
| `setFreeMinting(bool _freeMinting)`      | Enable/disable free minting by anyone.                       |

All of these require `DEFAULT_ADMIN_ROLE`.

Example:
```js
await kNFT.setRoyaltyEnforcement(false); // no royalty check
```

### Assigning Roles

To grant or revoke roles:
```js
// Example: give MINTER_ROLE to new address
const role = await kNFT.MINTER_ROLE(); // keccak256 hash
const tx = await kNFT.setRole(role, "0xSomeMinterAddress", true);
await tx.wait();
console.log("Role granted!");
```

### Updating Base URI

```js
await kNFT.setBaseURI("https://my-nft-api.com/metadata/");
```
Emits `BaseURIChanged(baseURI)` and `BatchMetadataUpdate(0, tokenIdCounter)` to notify marketplaces that metadata has changed.

---

## Events

- **`BaseURIChanged(string baseURI)`**: Emitted when the base URI is updated.
- **`DnaChanged(uint256 tokenId, uint256 dna)`**: When the full DNA for a token changes.
- **`DnaModified(uint256 tokenId, uint256 dna, uint256 inputValue, uint8 startIndex, uint8 endIndex)`**: When part of the DNA is updated.
- **`MetadataUpdate(uint256 tokenId)`** / **`BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId)`**: EIP-4906 events for updating metadata.
- **`RoleChanged(address addr, bytes32 role, bool enabled)`**: Whenever a role is granted/revoked.
- **`FreeMintingChanged(bool freeMinting)`**: When free minting is toggled.

