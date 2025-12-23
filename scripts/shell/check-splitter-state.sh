#!/bin/bash
#
# Check royalty splitter state
#

show_help() {
    cat << 'EOF'
NAME
    check-splitter-state.sh - Inspect SeaportAtomicRoyaltySplitter state

SYNOPSIS
    ./check-splitter-state.sh [OPTIONS]
    ./check-splitter-state.sh [SPLITTER_ADDRESS] [COLLECTION_ADDRESS]

DESCRIPTION
    Reads key state variables from a SeaportAtomicRoyaltySplitter contract
    to debug royalty distribution issues. Shows balance, push mode status,
    pending sales, and role assignments.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    SPLITTER_ADDRESS    Splitter contract address to inspect
                        (default: $SPLITTER_ADDRESS or 0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8)
    COLLECTION_ADDRESS  Associated NFT collection address
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)

ENVIRONMENT VARIABLES
    SPLITTER_ADDRESS    Default splitter address if not provided as argument
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    MAINNET_RPC_URL     RPC endpoint URL (required)

OUTPUT
    - ETH balance held by splitter
    - pushModeEnabled flag
    - hasPendingSale flag
    - lastSoldTokenId
    - Whether collection has COLLECTION_ROLE on splitter

EXAMPLES
    # Check default splitter
    ./check-splitter-state.sh

    # Check specific splitter and collection
    ./check-splitter-state.sh 0xSPLITTER... 0xCOLLECTION...
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

# Addresses from args, env, or defaults (v2)
SPLITTER="${1:-${SPLITTER_ADDRESS:-0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8}}"
COLLECTION="${2:-${COLLECTION_ADDRESS:-0x167a45aaC7a4512089eC6d401547351d7c73e66F}}"

echo "=== Splitter State ==="
echo "Address: $SPLITTER"
echo "Collection: $COLLECTION"
echo ""

echo "Balance:"
cast balance "$SPLITTER" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "pushModeEnabled:"
cast call "$SPLITTER" "pushModeEnabled()(bool)" --rpc-url "$MAINNET_RPC_URL" 2>/dev/null || echo "(function not available)"

echo ""
echo "hasPendingSale:"
cast call "$SPLITTER" "hasPendingSale()(bool)" --rpc-url "$MAINNET_RPC_URL" 2>/dev/null || echo "(function not available)"

echo ""
echo "lastSoldTokenId:"
cast call "$SPLITTER" "lastSoldTokenId()(uint256)" --rpc-url "$MAINNET_RPC_URL" 2>/dev/null || echo "(function not available)"

echo ""
echo "=== Check if NFT has COLLECTION_ROLE on splitter ==="
COLLECTION_ROLE=$(cast keccak "COLLECTION_ROLE")
echo "COLLECTION_ROLE hash: $COLLECTION_ROLE"
cast call "$SPLITTER" "hasRole(bytes32,address)(bool)" "$COLLECTION_ROLE" "$COLLECTION" --rpc-url "$MAINNET_RPC_URL"
