#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

echo "=== Verifying All Recently Deployed Contracts ==="
echo ""

# Contract addresses
IMPLEMENTATION="0x1A598f24C9798069B8B977B6Aa152629b378a40D"
FACTORY="0x3ECEce86800ad59AB923f3675Eb17ACa4Cc1111b"
BEACON="0xbbFeB9FB6601eFA2B66B8628A13F67e8e3A3DfCb"
COLLECTION="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"
SPLITTER="0xEA4F2710def06Ee87acDC8d449A198A08E650B64"

echo "1. Verifying KonduxImplementation..."
~/.foundry/bin/forge verify-contract \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --watch \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $IMPLEMENTATION \
    contracts/KonduxImplementation.sol:KonduxImplementation

echo ""
echo "2. Verifying KonduxBeaconFactory..."
~/.foundry/bin/forge verify-contract \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --constructor-args $(~/.foundry/bin/cast abi-encode "constructor(address)" $IMPLEMENTATION) \
    --watch \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $FACTORY \
    contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory

echo ""
echo "3. Verifying UpgradeableBeacon..."
~/.foundry/bin/forge verify-contract \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --constructor-args $(~/.foundry/bin/cast abi-encode "constructor(address,address)" $IMPLEMENTATION $FACTORY) \
    --watch \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $BEACON \
    node_modules/@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol:UpgradeableBeacon

echo ""
echo "4. Verifying BeaconProxy (Collection)..."
~/.foundry/bin/forge verify-contract \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --watch \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $COLLECTION \
    node_modules/@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy

echo ""
echo "5. Verifying KonduxRoyaltySplitter..."
# Get constructor args from the splitter
MANUFACTURER="0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114"
PARTNER="0x4936167DAE4160E5556D9294F2C78675659a3B63"
DEFAULT_CREATOR="0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"

~/.foundry/bin/forge verify-contract \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --constructor-args $(~/.foundry/bin/cast abi-encode "constructor(address,address,address,uint96,uint96,uint96,address)" $COLLECTION $MANUFACTURER $PARTNER 400 300 300 $FACTORY) \
    --watch \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $SPLITTER \
    contracts/KonduxRoyaltySplitter.sol:KonduxRoyaltySplitter

echo ""
echo "=== Verification Complete ==="
