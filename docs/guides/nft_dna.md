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