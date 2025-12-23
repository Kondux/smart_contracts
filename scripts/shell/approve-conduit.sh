#!/bin/bash
#
# Approve OpenSea Conduit for NFT collection
#

show_help() {
    cat << 'EOF'
NAME
    approve-conduit.sh - Approve OpenSea Seaport conduit for NFT transfers

SYNOPSIS
    ./approve-conduit.sh [OPTIONS]
    ./approve-conduit.sh [COLLECTION_ADDRESS]

DESCRIPTION
    Grants the OpenSea Seaport conduit approval to transfer NFTs from the
    specified collection on behalf of the signer. This is required before
    listing NFTs on OpenSea.

    Uses setApprovalForAll() to approve the conduit for all tokens.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    COLLECTION_ADDRESS  NFT collection contract address
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)

ENVIRONMENT VARIABLES
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    PROD_DEPLOYER_PK    Private key for signing the transaction (required)
    MAINNET_RPC_URL     RPC endpoint URL (required)

SEAPORT ADDRESSES
    Conduit: 0x1E0049783F008A0085193E00003D00cd54003c71 (OpenSea's official conduit)

EXAMPLES
    # Approve default collection
    ./approve-conduit.sh

    # Approve specific collection
    ./approve-conduit.sh 0x1234...
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

# Collection address from arg, env, or default v2
COLLECTION="${1:-${COLLECTION_ADDRESS:-0x167a45aaC7a4512089eC6d401547351d7c73e66F}}"
CONDUIT="0x1E0049783F008A0085193E00003D00cd54003c71"

echo "=== Approving OpenSea Conduit ==="
echo "Collection: $COLLECTION"
echo "Conduit: $CONDUIT"
echo ""

cast send "$COLLECTION" "setApprovalForAll(address,bool)" "$CONDUIT" true \
  --rpc-url "$MAINNET_RPC_URL" \
  --private-key "$PROD_DEPLOYER_PK"
