#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

echo "=== Deploying New Implementation to Mainnet ==="
echo ""

# Deploy new implementation (no constructor args)
~/.foundry/bin/forge create \
  --rpc-url "$MAINNET_RPC_URL" \
  --private-key "$PROD_DEPLOYER_PK" \
  --broadcast \
  contracts/KonduxImplementation.sol:KonduxImplementation

echo ""
echo "=== Done ==="
