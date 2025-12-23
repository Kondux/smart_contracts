#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Use existing implementation
export KONDUX_IMPL="0x1A598f24C9798069B8B977B6Aa152629b378a40D"
export PUBLIC_DEPLOYMENT="false"
export VERIFY="0"

echo "=== Deploying New Factory to Mainnet ==="
echo "Using existing implementation: $KONDUX_IMPL"
echo "Public deployment: $PUBLIC_DEPLOYMENT"
echo ""

~/.foundry/bin/forge script script/DeployKonduxBeaconFactory.s.sol:DeployKonduxBeaconFactoryScript \
  --rpc-url "$MAINNET_RPC_URL" \
  --broadcast \
  -vvvv
