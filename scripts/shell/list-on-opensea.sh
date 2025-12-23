#!/bin/bash
#
# Approve NFT collection for OpenSea listing via Seaport conduit
#

show_help() {
    cat << 'EOF'
NAME
    list-on-opensea.sh - Approve NFT collection for OpenSea listing

SYNOPSIS
    ./list-on-opensea.sh [OPTIONS]
    ./list-on-opensea.sh [TOKEN_ID] [COLLECTION_ADDRESS]

DESCRIPTION
    Approves the Seaport conduit to transfer NFTs from your collection,
    enabling listing on OpenSea. This is a prerequisite before creating
    actual listings.

    After running this script, use the Node.js listing script to create
    the actual OpenSea listing with EIP-712 signature.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    TOKEN_ID            Token ID to prepare for listing (default: 1)
    COLLECTION_ADDRESS  NFT collection contract address
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)

ENVIRONMENT VARIABLES
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    DEPLOYER_ADDRESS    Owner address for approval check
                        (default: 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2)
    PROD_DEPLOYER_PK    Private key for signing the transaction (required)
    MAINNET_RPC_URL     RPC endpoint URL (required)

SEAPORT ADDRESSES
    Conduit: 0x1E0049783F008A0085193E00003D00cd54003c71 (OpenSea's official conduit)

EXAMPLES
    # Approve for default collection
    ./list-on-opensea.sh

    # Approve specific token on specific collection
    ./list-on-opensea.sh 42 0x1234...

NEXT STEPS
    After approval, create the listing with:
    node scripts/util/listOnOpenSea.js <TOKEN_ID> <PRICE_ETH>
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
TOKEN_ID="${1:-1}"
COLLECTION="${2:-${COLLECTION_ADDRESS:-0x167a45aaC7a4512089eC6d401547351d7c73e66F}}"
SEAPORT_CONDUIT="0x1E0049783F008A0085193E00003D00cd54003c71"
OWNER="${DEPLOYER_ADDRESS:-0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2}"

echo "=== Setting Up OpenSea Listing ==="
echo "Collection: $COLLECTION"
echo "Token ID: $TOKEN_ID"
echo "Conduit: $SEAPORT_CONDUIT"
echo "Owner: $OWNER"
echo ""

# Check current approval
echo "Checking current approval..."
cast call "$COLLECTION" "isApprovedForAll(address,address)(bool)" "$OWNER" "$SEAPORT_CONDUIT" --rpc-url "$MAINNET_RPC_URL"

# Approve Seaport conduit
echo ""
echo "Approving..."
cast send "$COLLECTION" "setApprovalForAll(address,bool)" "$SEAPORT_CONDUIT" true \
    --private-key "$PROD_DEPLOYER_PK" \
    --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Approval Done ==="
echo ""
echo "To create the listing, run:"
echo "  node scripts/util/listOnOpenSea.js $TOKEN_ID <PRICE_ETH>"
