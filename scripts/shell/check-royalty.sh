#!/bin/bash
#
# Check ERC2981 royalty info for a collection
#

show_help() {
    cat << 'EOF'
NAME
    check-royalty.sh - Query ERC2981 royalty info for an NFT collection

SYNOPSIS
    ./check-royalty.sh [OPTIONS]
    ./check-royalty.sh [COLLECTION_ADDRESS] [TOKEN_ID] [SALE_PRICE_WEI]

DESCRIPTION
    Queries the ERC2981 royaltyInfo() function on an NFT collection to
    see what royalty amount and receiver would be returned for a given
    token and sale price. Useful for verifying royalty configuration.

OPTIONS
    -h, --help      Show this help message and exit

ARGUMENTS
    COLLECTION_ADDRESS  NFT collection contract address
                        (default: $COLLECTION_ADDRESS or 0x167a45aaC7a4512089eC6d401547351d7c73e66F)
    TOKEN_ID            Token ID to query royalty for (default: 1)
    SALE_PRICE_WEI      Hypothetical sale price in wei
                        (default: 1000000000000000000 = 1 ETH)

ENVIRONMENT VARIABLES
    COLLECTION_ADDRESS  Default collection address if not provided as argument
    MAINNET_RPC_URL     RPC endpoint URL (required)

OUTPUT
    - Royalty receiver address (typically the splitter)
    - Royalty amount in wei
    - Calculated percentage of sale price

EXAMPLES
    # Check royalty at 1 ETH sale price
    ./check-royalty.sh

    # Check royalty for token 42 at 0.5 ETH
    ./check-royalty.sh 0x1234... 42 500000000000000000

NOTE
    The royalty percentage is calculated as: (amount * 10000 / salePrice) / 100
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
TOKEN_ID="${2:-1}"
SALE_PRICE="${3:-1000000000000000000}"  # 1 ETH default

SALE_PRICE_ETH=$(echo "scale=6; $SALE_PRICE / 1000000000000000000" | bc | sed 's/^\./0./')

echo "=== Checking Royalty Info ==="
echo "Collection: $COLLECTION"
echo "Token ID: $TOKEN_ID"
echo "Sale Price: $SALE_PRICE wei ($SALE_PRICE_ETH ETH)"
echo ""

result=$(cast call "$COLLECTION" "royaltyInfo(uint256,uint256)(address,uint256)" "$TOKEN_ID" "$SALE_PRICE" --rpc-url "$MAINNET_RPC_URL")
echo "Royalty Info: $result"

# Parse and display
receiver=$(echo "$result" | head -1)
amount_raw=$(echo "$result" | tail -1)
# Extract just the number (remove cast's [notation])
amount=$(echo "$amount_raw" | awk '{print $1}')
echo ""
echo "Receiver: $receiver"
echo "Amount: $amount wei"

# Calculate ETH and percentage if amount is a number
if [[ "$amount" =~ ^[0-9]+$ ]] && [[ "$SALE_PRICE" =~ ^[0-9]+$ ]]; then
  eth_amount=$(echo "scale=6; $amount / 1000000000000000000" | bc | sed 's/^\./0./')
  echo "Amount: ${eth_amount} ETH"
  pct=$(echo "scale=2; $amount * 100 / $SALE_PRICE" | bc | sed 's/^\./0./')
  echo "Percentage: ${pct}%"
fi
