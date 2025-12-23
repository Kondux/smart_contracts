#!/bin/bash
#
# Update ERC2981 royalty on collection
#

show_help() {
    cat << 'EOF'
NAME
    update-erc2981-royalty.sh - Update ERC2981 royalty splits on an NFT collection

SYNOPSIS
    ./update-erc2981-royalty.sh [OPTIONS]
    ./update-erc2981-royalty.sh [MANUFACTURER_BP] [PARTNER_BP] [CREATOR_BP] [COLLECTION_ADDRESS]

DESCRIPTION
    Updates the ERC2981 royalty configuration on a Kondux NFT collection contract.
    This affects how royalties are reported to marketplaces that query royaltyInfo().

    The script calls setRoyaltySplits() which updates both the internal storage
    and the ERC2981 default royalty settings.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    MANUFACTURER_BP     Manufacturer royalty in basis points (default: 500 = 5%)
    PARTNER_BP          Partner royalty in basis points (default: 0 = 0%)
    CREATOR_BP          Creator royalty in basis points (default: 500 = 5%)
    COLLECTION_ADDRESS  NFT collection contract address
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)

ENVIRONMENT VARIABLES
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    PROD_DEPLOYER_PK    Private key for signing the transaction (required)
    MAINNET_RPC_URL     RPC endpoint URL (required)

EXAMPLES
    # Use defaults (5% manufacturer, 0% partner, 5% creator = 10% total)
    ./update-erc2981-royalty.sh

    # Set 3% manufacturer, 2% partner, 5% creator
    ./update-erc2981-royalty.sh 300 200 500

    # Set royalties on a specific collection
    ./update-erc2981-royalty.sh 500 0 500 0x1234...

NOTE
    1 basis point = 0.01%, so 500 BP = 5%
    Total royalty should typically not exceed 1000 BP (10%)
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
MANUFACTURER_BP="${1:-500}"
PARTNER_BP="${2:-0}"
CREATOR_BP="${3:-500}"
COLLECTION="${4:-${COLLECTION_ADDRESS:-0x167a45aaC7a4512089eC6d401547351d7c73e66F}}"

TOTAL_BP=$((MANUFACTURER_BP + PARTNER_BP + CREATOR_BP))
TOTAL_PCT=$(echo "scale=2; $TOTAL_BP / 100" | bc)

echo "=== Updating ERC2981 Royalty ==="
echo "Collection: $COLLECTION"
echo ""
echo "New splits:"
echo "  Manufacturer: $MANUFACTURER_BP BP ($(echo "scale=2; $MANUFACTURER_BP / 100" | bc)%)"
echo "  Partner: $PARTNER_BP BP ($(echo "scale=2; $PARTNER_BP / 100" | bc)%)"
echo "  Creator: $CREATOR_BP BP ($(echo "scale=2; $CREATOR_BP / 100" | bc)%)"
echo "  Total: $TOTAL_BP BP (${TOTAL_PCT}%)"
echo ""

# Call setRoyaltySplits which updates storage and ERC2981 default royalty
cast send "$COLLECTION" \
  "setRoyaltySplits(uint96,uint96,uint96)" \
  "$MANUFACTURER_BP" "$PARTNER_BP" "$CREATOR_BP" \
  --private-key "$PROD_DEPLOYER_PK" \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verifying new royalty ==="
echo "Testing royaltyInfo for token 1 at 1 ETH sale price:"
cast call "$COLLECTION" \
  "royaltyInfo(uint256,uint256)(address,uint256)" 1 1000000000000000000 \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Done ==="
