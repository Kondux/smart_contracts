# Kondux NFT DNA

Every Kondux NFT has a DNA that is stored in the Kondux_NFT contract.
The DNA is a uint256 variable in the Kondux_NFT contract.
It stores the genes of the NFT. The DNA is meant to be loaded into games or applications to provide users a unique asset, owned by the user.

The gene is a number that represents the NFT's attributes, directly or indirectly. A Kondux DNA have a undefined amount of genes, but it's always a number and always fits in a 256 bits space. For example, a Kondux DNA can have up to 256 genes of 1 bit each. Or 32 genes of 8 bits each (1 byte). Or 1 gene of 4 bytes, followed by 2 gene of 1 byte, followed by 13 gene of 2 bytes. Etc.

Example of DNA:

table:nft_dna

    |----|----|----|----| (...) |----|----|----|----|
    |  0 |  1 |  2 |  3 | (...) | 29 | 30 | 31 | 32 |    bytes
    | 02 | 4e | 81 | aa | (...) | 3b | c2 | d8 | ee |    genes

    attributes:
    - 0: NFT collection
      - 02 is the collection of Alien NFT
    - 1: Base color
      - 4e is the base color of Grey skin tone
    - 2: Skin base pattern
      - 81 is the base pattern of a square
    - 3: Avatar size
      - aa is the size of the avatar in centimeters (aa = 170 cm)
    (...)
    And so on up to the last gene (byte).


The DNA protocol is currently in development. There's no official protocol or mapping yet.

The DNA is not meant to be human readable.

# How to Read Genes Using the `readGen` Function in Solidity

This guide will explain how to read genes from a token's DNA value using the `readGen` function provided in the given Solidity code snippet.

## Function Signature

```solidity
function readGen(uint256 _tokenID, uint8 startIndex, uint8 endIndex) public view returns (int256)
```

## Parameters

- `_tokenID`: The ID of the token you want to extract the gene information from.
- `startIndex`: The starting index of the byte range in the DNA value you want to extract.
- `endIndex`: The ending index of the byte range in the DNA value you want to extract.

## Usage

1. First, you need to have a valid token ID for which you want to extract the gene information. The token ID should correspond to an existing token in the contract.

2. Determine the range of bytes you want to extract from the DNA value. The `startIndex` should be less than the `endIndex`, and the `endIndex` should be less than or equal to 32 (the DNA value has 32 bytes).

3. Call the `readGen` function with the token ID and the byte range you have determined. The function will return the extracted value as an `int256`.

### Example

Suppose you have a token with ID `12345`, and you want to extract the gene information from the bytes between positions 2 and 5 in the DNA value. You can call the `readGen` function like this:

```solidity
int256 extractedValue = readGen(12345, 2, 5);
```

The `extractedValue` will now contain the value extracted from the DNA value of the token with ID `12345` in the specified byte range (2 to 5).

## Important Notes

- Make sure the range you specify with `startIndex` and `endIndex` is valid. If the range is invalid, the function will revert with an "Invalid range" error message.

- The byte positions in the DNA value are stored in big-endian, so the function reverses the index while reading the bytes. Keep this in mind when specifying the byte range.

- The extracted value will be returned as an `int256`. You may need to convert or cast it to a different type, depending on your specific use case.

- Remember that the function has the `view` modifier, which means it doesn't modify the contract's state and can be called without incurring any gas costs.