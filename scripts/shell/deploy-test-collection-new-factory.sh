#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Use the NEW factory
export FACTORY_ADDRESS="0xa265a01205f304F2652277AaC924AB56D2e0Cf77"
export COLLECTION_NAME="Kondux Test V2"
export COLLECTION_SYMBOL="KNDXV2"
export MAX_SUPPLY="1000"
export DEPLOY_SPLITTER="true"
export RUN_SMOKE_TEST="true"
export VERIFY="0"

# Royalty cuts (5% total: 2% manufacturer, 1.5% partner, 1.5% creator)
export MANUFACTURER_CUT_BP="200"
export PARTNER_CUT_BP="150"
export CREATOR_CUT_BP="150"

echo "=== Deploying Test Collection via New Factory ==="
echo "Factory: $FACTORY_ADDRESS"
echo "Collection Name: $COLLECTION_NAME"
echo "Symbol: $COLLECTION_SYMBOL"
echo "Max Supply: $MAX_SUPPLY"
echo "Royalty Cuts: $MANUFACTURER_CUT_BP + $PARTNER_CUT_BP + $CREATOR_CUT_BP = $((MANUFACTURER_CUT_BP + PARTNER_CUT_BP + CREATOR_CUT_BP)) BP"
echo ""

~/.foundry/bin/forge script script/DeployCollectionWithSplitter.s.sol:DeployCollectionWithSplitterScript \
  --rpc-url "$MAINNET_RPC_URL" \
  --broadcast \
  -vvvv
