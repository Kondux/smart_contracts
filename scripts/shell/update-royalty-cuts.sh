#!/bin/bash
#
# Update royalty cut percentages on splitter via factory
#

show_help() {
    cat << 'EOF'
NAME
    update-royalty-cuts.sh - Update royalty cut percentages on a Seaport splitter

SYNOPSIS
    ./update-royalty-cuts.sh [OPTIONS]
    ./update-royalty-cuts.sh [MANUFACTURER_BP] [PARTNER_BP] [CREATOR_BP] [SPLITTER_ADDRESS] [FACTORY_ADDRESS]

DESCRIPTION
    Updates the royalty cut percentages on a SeaportAtomicRoyaltySplitter contract
    via the factory contract. This determines how royalties are distributed when
    NFT sales occur through Seaport.

    The factory must have admin role on the splitter to execute this operation.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    MANUFACTURER_BP     Manufacturer cut in basis points (default: 500 = 5%)
    PARTNER_BP          Partner cut in basis points (default: 0 = 0%)
    CREATOR_BP          Creator cut in basis points (default: 500 = 5%)
    SPLITTER_ADDRESS    Splitter contract address
                        (default: $SPLITTER_ADDRESS or 0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8)
    FACTORY_ADDRESS     Factory contract address
                        (default: $FACTORY_ADDRESS or 0xa265a01205f304F2652277AaC924AB56D2e0Cf77)

ENVIRONMENT VARIABLES
    SPLITTER_ADDRESS    Default splitter address if not provided as argument
    FACTORY_ADDRESS     Default factory address if not provided as argument
    PROD_DEPLOYER_PK    Private key for signing the transaction (required)
    MAINNET_RPC_URL     RPC endpoint URL (required)

EXAMPLES
    # Use defaults (5% manufacturer, 0% partner, 5% creator)
    ./update-royalty-cuts.sh

    # Set 3% manufacturer, 2% partner, 5% creator
    ./update-royalty-cuts.sh 300 200 500

    # Update specific splitter via specific factory
    ./update-royalty-cuts.sh 500 0 500 0xSPLITTER... 0xFACTORY...

NOTE
    1 basis point = 0.01%, so 500 BP = 5%
    These cuts determine the split ratios when royalties are distributed
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
SPLITTER="${4:-${SPLITTER_ADDRESS:-0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8}}"
FACTORY="${5:-${FACTORY_ADDRESS:-0xa265a01205f304F2652277AaC924AB56D2e0Cf77}}"

TOTAL_BP=$((MANUFACTURER_BP + PARTNER_BP + CREATOR_BP))
TOTAL_PCT=$(echo "scale=2; $TOTAL_BP / 100" | bc)

echo "=== Updating Royalty Cuts ==="
echo "Splitter: $SPLITTER"
echo "Factory: $FACTORY"
echo ""
echo "New cuts:"
echo "  Manufacturer: $MANUFACTURER_BP BP ($(echo "scale=2; $MANUFACTURER_BP / 100" | bc)%)"
echo "  Partner: $PARTNER_BP BP ($(echo "scale=2; $PARTNER_BP / 100" | bc)%)"
echo "  Creator: $CREATOR_BP BP ($(echo "scale=2; $CREATOR_BP / 100" | bc)%)"
echo "  Total: $TOTAL_BP BP (${TOTAL_PCT}%)"
echo ""

# Update cuts via factory (which has admin role on splitter)
cast send "$FACTORY" "setCutsOnSplitter(address,uint96,uint96,uint96)" "$SPLITTER" "$MANUFACTURER_BP" "$PARTNER_BP" "$CREATOR_BP" \
    --private-key "$PROD_DEPLOYER_PK" \
    --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verifying ==="
echo "Manufacturer cut BP:"
cast call "$SPLITTER" "manufacturerCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo "Partner cut BP:"
cast call "$SPLITTER" "partnerCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo "Creator cut BP:"
cast call "$SPLITTER" "defaultCreatorCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo ""
echo "=== Done ==="
