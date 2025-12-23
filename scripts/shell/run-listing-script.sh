#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

echo "=== Running ListNewNFT Script ==="
~/.foundry/bin/forge script script/ListNewNFT.s.sol --rpc-url "$MAINNET_RPC_URL"
