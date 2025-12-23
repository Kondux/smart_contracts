#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

FACTORY="0x3ECEce86800ad59AB923f3675Eb17ACa4Cc1111b"

echo "=== Current Factory Configuration ==="
echo "Factory: $FACTORY"

BEACON=$(~/.foundry/bin/cast call $FACTORY "beacon()(address)" --rpc-url "$MAINNET_RPC_URL")
echo "Beacon: $BEACON"

IMPL=$(~/.foundry/bin/cast call $BEACON "implementation()(address)" --rpc-url "$MAINNET_RPC_URL")
echo "Implementation: $IMPL"
