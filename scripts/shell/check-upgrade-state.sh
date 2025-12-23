#!/bin/bash
#
# Check NFT proxy upgrade state (ERC1967)
#

show_help() {
    cat << 'EOF'
NAME
    check-upgrade-state.sh - Inspect ERC1967 proxy state for upgradeable NFT

SYNOPSIS
    ./check-upgrade-state.sh [OPTIONS]
    ./check-upgrade-state.sh [COLLECTION_ADDRESS]

DESCRIPTION
    Reads the ERC1967 storage slots to inspect the proxy state of an
    upgradeable NFT collection. Shows implementation address, admin,
    and key contract state like royalty splitter and admin roles.

    Useful for debugging upgrades and verifying proxy configuration.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    COLLECTION_ADDRESS  NFT collection proxy address to inspect
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)

ENVIRONMENT VARIABLES
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    MAINNET_RPC_URL     RPC endpoint URL (required)

ERC1967 SLOTS
    Implementation: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
    Admin:          0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103

OUTPUT
    - Implementation address (current logic contract)
    - Admin address (who can upgrade)
    - Royalty splitter address
    - DEFAULT_ADMIN_ROLE holder count and first admin

EXAMPLES
    # Check default collection
    ./check-upgrade-state.sh

    # Check specific collection
    ./check-upgrade-state.sh 0x1234...
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

echo "=== NFT Proxy State ==="
echo "Address: $COLLECTION"
echo ""

echo "Implementation slot (ERC1967):"
cast storage "$COLLECTION" 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Admin slot (ERC1967):"
cast storage "$COLLECTION" 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Check royaltySplitter variable ==="
cast call "$COLLECTION" "royaltySplitter()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Check DEFAULT_ADMIN_ROLE holder ==="
DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
cast call "$COLLECTION" "getRoleMemberCount(bytes32)(uint256)" "$DEFAULT_ADMIN_ROLE" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "First admin:"
cast call "$COLLECTION" "getRoleMember(bytes32,uint256)(address)" "$DEFAULT_ADMIN_ROLE" 0 --rpc-url "$MAINNET_RPC_URL"
