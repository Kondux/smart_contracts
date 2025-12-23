#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

COLLECTION="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"
SEAPORT="0x0000000000000068F116a894984e2DB1123eB395"
SELLER="0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"

echo "=== Step 1: Increment Seaport Counter to Cancel All Orders ==="
# This invalidates ALL orders from this seller with counter 0
~/.foundry/bin/cast send $SEAPORT "incrementCounter()" \
  --private-key "$PROD_DEPLOYER_PK" \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Step 2: Force OpenSea to Refresh Collection Metadata ==="
# Refresh collection metadata via OpenSea API
curl -X POST "https://api.opensea.io/api/v2/chain/ethereum/contract/$COLLECTION/nfts/refresh" \
  -H "X-API-KEY: $OPENSEA_API_KEY"

echo ""
echo "=== Step 3: Verify New Counter ==="
~/.foundry/bin/cast call $SEAPORT "getCounter(address)(uint256)" $SELLER --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Done ==="
echo "Old orders with counter 0 are now invalid."
echo "Wait a few minutes for OpenSea to update, then create a new listing with 5% royalty."
