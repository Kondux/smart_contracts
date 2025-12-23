#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

echo "=== Verifying Contracts on Etherscan ==="
echo ""

# New Factory
echo "1. Verifying New Factory (0xa265a01205f304F2652277AaC924AB56D2e0Cf77)..."
~/.foundry/bin/forge verify-contract \
  --chain-id 1 \
  --compiler-version 0.8.30 \
  --num-of-optimizations 200 \
  --via-ir \
  --constructor-args $(~/.foundry/bin/cast abi-encode "constructor(address)" "0x1A598f24C9798069B8B977B6Aa152629b378a40D") \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --watch \
  0xa265a01205f304F2652277AaC924AB56D2e0Cf77 \
  contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory

echo ""
echo "2. Verifying New Splitter (0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8)..."
# Constructor args: collection, manufacturerWallet, partnerWallet, manufacturerCutBP, partnerCutBP, defaultCreatorCutBP, defaultCreatorWallet, admin
SPLITTER_ARGS=$(~/.foundry/bin/cast abi-encode "constructor(address,address,address,uint96,uint96,uint96,address,address)" \
  "0x167a45aaC7a4512089eC6d401547351d7c73e66F" \
  "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2" \
  "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2" \
  200 150 150 \
  "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2" \
  "0xa265a01205f304F2652277AaC924AB56D2e0Cf77")
~/.foundry/bin/forge verify-contract \
  --chain-id 1 \
  --compiler-version 0.8.30 \
  --num-of-optimizations 200 \
  --via-ir \
  --constructor-args "$SPLITTER_ARGS" \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --watch \
  0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8 \
  contracts/KonduxRoyaltySplitter.sol:KonduxRoyaltySplitter

echo ""
echo "3. Verifying Implementation (if not already verified)..."
~/.foundry/bin/forge verify-contract \
  --chain-id 1 \
  --compiler-version 0.8.30 \
  --num-of-optimizations 200 \
  --via-ir \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --watch \
  0x1A598f24C9798069B8B977B6Aa152629b378a40D \
  contracts/KonduxImplementation.sol:KonduxImplementation

echo ""
echo "=== Done ==="
