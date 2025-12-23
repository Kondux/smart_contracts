#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

SPLITTER="0xEA4F2710def06Ee87acDC8d449A198A08E650B64"
COLLECTION="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"
FACTORY="0x3ECEce86800ad59AB923f3675Eb17ACa4Cc1111b"

echo "=== Splitter Configuration ==="
echo "Balance (wei):"
~/.foundry/bin/cast balance $SPLITTER --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Push mode enabled:"
~/.foundry/bin/cast call $SPLITTER "pushModeEnabled()(bool)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Has pending sale:"
~/.foundry/bin/cast call $SPLITTER "hasPendingSale()(bool)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Last sold token ID:"
~/.foundry/bin/cast call $SPLITTER "lastSoldTokenId()(uint256)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Collection Config ==="
echo "Royalty Splitter on collection:"
~/.foundry/bin/cast call $COLLECTION "royaltySplitter()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Beacon Implementation ==="
BEACON=$(~/.foundry/bin/cast call $FACTORY "beacon()(address)" --rpc-url "$MAINNET_RPC_URL")
echo "Beacon: $BEACON"

echo ""
echo "Implementation address:"
~/.foundry/bin/cast call $BEACON "implementation()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Checking if _update hook works ==="
echo "Splitter has COLLECTION_ROLE for collection?"
COLLECTION_ROLE=$(~/.foundry/bin/cast call $SPLITTER "COLLECTION_ROLE()(bytes32)" --rpc-url "$MAINNET_RPC_URL")
echo "COLLECTION_ROLE: $COLLECTION_ROLE"
~/.foundry/bin/cast call $SPLITTER "hasRole(bytes32,address)(bool)" "$COLLECTION_ROLE" "$COLLECTION" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Manual sweep to distribute stuck ETH ==="
echo "This will distribute the 0.00005 ETH to manufacturer/partner/creator"
# Uncomment to run:
# ~/.foundry/bin/cast send $SPLITTER "sweepETH()" --private-key "$PROD_DEPLOYER_PK" --rpc-url "$MAINNET_RPC_URL"
