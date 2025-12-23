#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
~/.foundry/bin/forge script script/CreateEnforcedRoyaltyListing.s.sol:CreateEnforcedRoyaltyListingScript --rpc-url "$MAINNET_RPC_URL" --broadcast -vvv
