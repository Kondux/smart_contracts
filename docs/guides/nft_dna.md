# Kondux NFT DNA System

## Overview

Every Kondux NFT contains a **DNA** value - a 256-bit (`uint256`) on-chain data structure that encodes the NFT's unique attributes, traits, and properties. The DNA system enables:

- **On-chain trait storage** without relying on external metadata
- **Game/application integration** with deterministic asset properties
- **Dynamic attributes** that can be modified by authorized contracts
- **Staking boost calculations** based on "bonus genes"

---

## Table of Contents

- [DNA Structure](#dna-structure)
- [Reading DNA](#reading-dna)
- [Writing DNA](#writing-dna)
- [Integration Examples](#integration-examples)
- [Use Cases](#use-cases)
- [Technical Reference](#technical-reference)

---

## DNA Structure

### Byte Layout

The DNA is stored as a `uint256` (32 bytes / 256 bits) in the `indexDna[tokenId]` mapping.

```
Byte Position:  |  0 |  1 |  2 |  3 | ... | 28 | 29 | 30 | 31 |
Hex Values:     | 02 | 4e | 81 | aa | ... | 3b | c2 | d8 | ee |
                ↑                                              ↑
            MSB (Most Significant Byte)              LSB (Least Significant Byte)
```

### Gene Encoding

Genes can occupy any number of contiguous bytes:

| Configuration | Example Use Case |
|---------------|------------------|
| 256 x 1-bit genes | Boolean flags (has_trait, is_unlocked) |
| 32 x 8-bit genes | Color values, level indicators (0-255) |
| 16 x 16-bit genes | Larger numeric values (0-65535) |
| Mixed sizes | Collection ID (1 byte) + Stats (2 bytes each) + Bonus (1 byte) |

### Example Gene Map

```
Byte 0:     Collection ID (0x02 = Alien Collection)
Byte 1:     Base Color (0x4e = Grey skin tone)
Byte 2:     Pattern Type (0x81 = Square pattern)
Byte 3:     Avatar Height (0xaa = 170 cm)
Bytes 4-5:  Power Level (16-bit value)
Byte 31:    Bonus Gene (used for staking boosts, 1-5%)
```

> **Note**: The exact gene mapping is application-specific. Each collection defines its own encoding schema.

---

## Reading DNA

### Full DNA Retrieval

```solidity
// Get the complete 256-bit DNA value
function getDna(uint256 tokenId) public view returns (uint256)
```

```javascript
// JavaScript example
const dna = await kNFT.getDna(tokenId);
console.log("DNA:", dna.toHexString()); // 0x024e81aa...
```

### Partial Gene Extraction

Use `readGen` to extract specific byte ranges:

```solidity
function readGen(
    uint256 _tokenID,
    uint8 startIndex,
    uint8 endIndex
) public view returns (int256)
```

**Parameters:**
- `_tokenID`: Token ID to query
- `startIndex`: Starting byte position (inclusive, 0-31)
- `endIndex`: Ending byte position (exclusive, must be > startIndex)

**Returns:** Extracted value as `int256`

### Reading Examples

```javascript
// Read byte 0 (Collection ID)
const collectionId = await kNFT.readGen(tokenId, 0, 1);

// Read bytes 4-5 (16-bit power level)
const powerLevel = await kNFT.readGen(tokenId, 4, 6);

// Read byte 31 (Bonus gene for staking)
const bonusGene = await kNFT.readGen(tokenId, 31, 32);
```

```solidity
// Solidity example
int256 collectionId = readGen(tokenId, 0, 1);    // Returns byte 0
int256 powerLevel = readGen(tokenId, 4, 6);      // Returns bytes 4-5 as uint16
int256 bonusGene = readGen(tokenId, 31, 32);     // Returns byte 31
```

---

## Writing DNA

### Full DNA Assignment

Requires `DNA_MODIFIER_ROLE`:

```solidity
function setDna(uint256 tokenId, uint256 dna) external
```

```javascript
// Set entire DNA
const newDna = ethers.BigNumber.from("0x024e81aa...");
await kNFT.setDna(tokenId, newDna);
// Emits: DnaChanged(tokenId, dna)
```

### Batch DNA Assignment

Set DNA for multiple tokens efficiently:

```solidity
function batchSetDna(uint256[] calldata tokenIds, uint256[] calldata dnas) external
```

### Partial Gene Modification

Use `writeGen` to modify specific bytes without affecting others:

```solidity
function writeGen(
    uint256 _tokenID,
    uint256 _inputValue,
    uint8 _startIndex,
    uint8 _endIndex
) external
```

**Parameters:**
- `_tokenID`: Token ID to modify
- `_inputValue`: New value to write
- `_startIndex`: Starting byte position
- `_endIndex`: Ending byte position

```javascript
// Update only the power level (bytes 4-5)
await kNFT.writeGen(tokenId, 5000, 4, 6);
// Emits: DnaModified(tokenId, dna, inputValue, startIndex, endIndex)

// Update bonus gene (byte 31)
await kNFT.writeGen(tokenId, 5, 31, 32);
```

---

## Integration Examples

### Staking Boost Calculation

The staking contract reads the bonus gene to calculate reward boosts:

```javascript
// Staking contract reads bonus genes from user's kNFTs
async function calculateKNFTBoost(userAddress) {
    const kNFTs = await getOwnedTokens(userAddress);
    const boosts = [];

    for (const tokenId of kNFTs) {
        // Read bonus gene from byte 31
        const bonusGene = await kNFT.readGen(tokenId, 31, 32);
        // Bonus gene value 1-5 = 1-5% boost
        boosts.push(Number(bonusGene));
    }

    // Sum top 5 boosts
    return boosts.sort((a, b) => b - a).slice(0, 5).reduce((a, b) => a + b, 0);
}
```

### Game Integration

```javascript
// Load character stats from DNA
async function loadCharacter(tokenId) {
    const dna = await kNFT.getDna(tokenId);

    return {
        collection: await kNFT.readGen(tokenId, 0, 1),
        skinColor: await kNFT.readGen(tokenId, 1, 2),
        pattern: await kNFT.readGen(tokenId, 2, 3),
        height: await kNFT.readGen(tokenId, 3, 4),
        powerLevel: await kNFT.readGen(tokenId, 4, 6),
        // ... more attributes
    };
}
```

### Metadata Generation

```javascript
// Generate metadata from DNA for IPFS/API
function generateMetadata(tokenId, dna) {
    const traits = [];

    // Extract and decode each gene
    const collection = (dna >> 248n) & 0xFFn;
    const color = (dna >> 240n) & 0xFFn;

    traits.push({
        trait_type: "Collection",
        value: COLLECTION_NAMES[collection]
    });

    traits.push({
        trait_type: "Skin Color",
        value: COLOR_NAMES[color]
    });

    return {
        name: `Kondux #${tokenId}`,
        description: "A unique Kondux NFT",
        attributes: traits
    };
}
```

---

## Use Cases

| Use Case | Implementation |
|----------|----------------|
| **Avatars** | Store appearance traits (color, pattern, size) |
| **Gaming** | Character stats, equipment, level progression |
| **Staking** | Bonus genes affect reward multipliers |
| **Rarity** | Trait combinations determine rarity tiers |
| **Evolution** | Modify DNA to unlock new traits over time |
| **Breeding** | Combine parent DNAs to create offspring |

---

## Technical Reference

### Events

```solidity
// Emitted when full DNA is set
event DnaChanged(uint256 indexed tokenId, uint256 dna);

// Emitted when partial DNA is modified
event DnaModified(
    uint256 indexed tokenId,
    uint256 dna,
    uint256 inputValue,
    uint8 startIndex,
    uint8 endIndex
);

// EIP-4906: Triggers metadata refresh
event MetadataUpdate(uint256 indexed tokenId);
```

### Access Control

| Function | Required Role |
|----------|---------------|
| `getDna()` | Public (view) |
| `readGen()` | Public (view) |
| `setDna()` | `DNA_MODIFIER_ROLE` |
| `batchSetDna()` | `DNA_MODIFIER_ROLE` |
| `writeGen()` | `DNA_MODIFIER_ROLE` |

### Storage Layout

```solidity
// Per-token DNA storage
mapping(uint256 => uint256) internal indexDna;
```

### Byte Order

DNA uses **big-endian** storage:
- Byte 0 is the most significant byte (leftmost)
- Byte 31 is the least significant byte (rightmost)
- `readGen` internally handles byte reversal for correct extraction

### Gas Considerations

| Operation | Approximate Gas |
|-----------|-----------------|
| `getDna()` | ~2,500 (view) |
| `readGen()` | ~3,000 (view) |
| `setDna()` | ~25,000 |
| `writeGen()` | ~30,000 |
| `batchSetDna(10)` | ~200,000 |

---

## Best Practices

1. **Define gene maps upfront** - Document which bytes encode which attributes
2. **Use consistent encoding** - Stick to standard sizes (1, 2, 4 bytes) for easier parsing
3. **Reserve bytes** - Leave unused bytes for future expansion
4. **Cache DNA reads** - Batch multiple `readGen` calls when possible
5. **Validate ranges** - Always ensure `startIndex < endIndex <= 32`
6. **Consider upgradability** - DNA interpretation can evolve without contract changes

---

## Related Documentation

- [KonduxImplementation.md](./KonduxImplementation.md) - Full NFT contract reference
- [staking-system.md](./staking-system.md) - How DNA affects staking rewards
- [kondux-royalty-model.md](../kondux-royalty-model.md) - Royalty system overview
