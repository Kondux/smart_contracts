#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
unset VERIFY

echo "=== Copying Settings to New NFT ==="
~/.foundry/bin/forge script script/CopyNFTSettings.s.sol:CopyNFTSettingsScript \
    --rpc-url "$MAINNET_RPC_URL" \
    --broadcast \
    -vvv

echo ""
echo "=== Done ==="
