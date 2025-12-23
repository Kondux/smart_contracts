#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

BATCH_MINTER="0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF"
NEW_NFT="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"

echo "=== Updating Batch Minter ==="
echo "Batch Minter: $BATCH_MINTER"
echo "New NFT Collection: $NEW_NFT"
echo ""

echo "Current kondux target:"
~/.foundry/bin/cast call $BATCH_MINTER "kondux()(address)" --rpc-url "$MAINNET_RPC_URL"
echo ""

echo "Setting new target..."
~/.foundry/bin/cast send $BATCH_MINTER "setKNFT(address)" $NEW_NFT \
    --private-key "$PROD_DEPLOYER_PK" \
    --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Verifying new target:"
~/.foundry/bin/cast call $BATCH_MINTER "kondux()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Done ==="
