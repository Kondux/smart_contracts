#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

IMPLEMENTATION="0x1A598f24C9798069B8B977B6Aa152629b378a40D"
FACTORY="0x3ECEce86800ad59AB923f3675Eb17ACa4Cc1111b"

CONSTRUCTOR_ARGS=$(~/.foundry/bin/cast abi-encode "constructor(address)" $IMPLEMENTATION)

echo "Verifying KonduxBeaconFactory..."
echo "Constructor args: $CONSTRUCTOR_ARGS"

~/.foundry/bin/forge verify-contract \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --via-ir \
    --flatten \
    --constructor-args "$CONSTRUCTOR_ARGS" \
    --watch \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $FACTORY \
    contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory
