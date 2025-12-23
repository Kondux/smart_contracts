#!/bin/bash
#
# Mint a single NFT with DNA
#

show_help() {
    cat << 'EOF'
NAME
    mint-one-nft.sh - Mint a single NFT with DNA to a Kondux collection

SYNOPSIS
    ./mint-one-nft.sh [OPTIONS]
    ./mint-one-nft.sh [TO_ADDRESS] [DNA] [COLLECTION_ADDRESS]

DESCRIPTION
    Mints a single NFT to the specified address with the given DNA value.
    DNA is a uint256 that encodes the NFT's traits and metadata.

    Requires MINTER_ROLE on the collection contract.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    TO_ADDRESS          Recipient address for the minted NFT
                        (default: $DEPLOYER_ADDRESS or 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2)
    DNA                 DNA value (uint256) encoding traits (default: 12345)
    COLLECTION_ADDRESS  NFT collection contract address
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)

ENVIRONMENT VARIABLES
    DEPLOYER_ADDRESS    Default recipient address if not provided as argument
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    PROD_DEPLOYER_PK    Private key for signing the transaction (required)
    MAINNET_RPC_URL     RPC endpoint URL (required)

EXAMPLES
    # Mint to self with default DNA
    ./mint-one-nft.sh

    # Mint to specific address with custom DNA
    ./mint-one-nft.sh 0xRecipient... 98765

    # Mint to specific address, DNA, and collection
    ./mint-one-nft.sh 0xRecipient... 98765 0xCollection...

NOTE
    The minting account must have MINTER_ROLE on the collection contract.
    DNA encoding is collection-specific and determines on-chain traits.
EOF
    exit 0
}

# Parse options
case "${1:-}" in
    -h|--help) show_help ;;
esac

cd "$(dirname "$0")/../.."
[ -f .env ] && { sed -i "s/\r$//" .env 2>/dev/null; set -a && source .env && set +a; }
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
export PATH="$HOME/.foundry/bin:$PATH"

# Parameters from args or env with defaults
TO="${1:-${DEPLOYER_ADDRESS:-0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2}}"
DNA="${2:-12345}"
COLLECTION="${3:-${COLLECTION_ADDRESS:-0x167a45aaC7a4512089eC6d401547351d7c73e66F}}"

echo "=== Minting NFT ==="
echo "Collection: $COLLECTION"
echo "Minting to: $TO"
echo "DNA: $DNA"
echo ""

cast send "$COLLECTION" "safeMint(address,uint256)" "$TO" "$DNA" \
    --private-key "$PROD_DEPLOYER_PK" \
    --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Checking total supply ==="
cast call "$COLLECTION" "totalSupply()(uint256)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Done ==="
