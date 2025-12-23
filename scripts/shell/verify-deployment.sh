#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

echo "=== Verifying New Deployment ==="
echo ""

# New deployed addresses
FACTORY="0x3ECEce86800ad59AB923f3675Eb17ACa4Cc1111b"
IMPLEMENTATION="0x1A598f24C9798069B8B977B6Aa152629b378a40D"
COLLECTION="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"
SPLITTER="0xEA4F2710def06Ee87acDC8d449A198A08E650B64"

echo "Factory: $FACTORY"
echo "Implementation: $IMPLEMENTATION"
echo "Collection: $COLLECTION"
echo "Splitter: $SPLITTER"
echo ""

echo "=== 1. Check Factory Beacon ==="
echo "Beacon address:"
~/.foundry/bin/cast call $FACTORY "beacon()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== 2. Check Collection Name and Symbol ==="
echo "Name:"
~/.foundry/bin/cast call $COLLECTION "name()(string)" --rpc-url "$MAINNET_RPC_URL"
echo "Symbol:"
~/.foundry/bin/cast call $COLLECTION "symbol()(string)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== 3. Check Splitter Configuration ==="
echo "Collection:"
~/.foundry/bin/cast call $SPLITTER "collection()(address)" --rpc-url "$MAINNET_RPC_URL"
echo "Push mode enabled:"
~/.foundry/bin/cast call $SPLITTER "pushModeEnabled()(bool)" --rpc-url "$MAINNET_RPC_URL"
echo "Manufacturer cut BP:"
~/.foundry/bin/cast call $SPLITTER "manufacturerCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo "Partner cut BP:"
~/.foundry/bin/cast call $SPLITTER "partnerCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo "Creator cut BP:"
~/.foundry/bin/cast call $SPLITTER "defaultCreatorCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== 4. Check ERC2981 Royalty Info ==="
echo "Royalty info for tokenId 0, sale price 1 ETH:"
~/.foundry/bin/cast call $COLLECTION "royaltyInfo(uint256,uint256)(address,uint256)" 0 1000000000000000000 --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== 5. Check Collection has COLLECTION_ROLE on Splitter ==="
COLLECTION_ROLE=$(~/.foundry/bin/cast keccak "COLLECTION_ROLE")
echo "COLLECTION_ROLE hash: $COLLECTION_ROLE"
~/.foundry/bin/cast call $SPLITTER "hasRole(bytes32,address)(bool)" "$COLLECTION_ROLE" "$COLLECTION" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== 6. Check royaltySplitter on Collection ==="
~/.foundry/bin/cast call $COLLECTION "royaltySplitter()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verification Complete ==="
