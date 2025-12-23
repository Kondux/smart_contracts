#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

SPLITTER="0xEA4F2710def06Ee87acDC8d449A198A08E650B64"

echo "=== Sweeping ETH from Splitter ==="
echo "Splitter: $SPLITTER"
echo ""

echo "Current balance:"
~/.foundry/bin/cast balance $SPLITTER --rpc-url "$MAINNET_RPC_URL"

FACTORY="0x3ECEce86800ad59AB923f3675Eb17ACa4Cc1111b"
DEPLOYER="0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"

echo ""
echo "Checking ADMIN_ROLE..."
ADMIN_ROLE=$(~/.foundry/bin/cast call $SPLITTER "ADMIN_ROLE()(bytes32)" --rpc-url "$MAINNET_RPC_URL")
echo "ADMIN_ROLE: $ADMIN_ROLE"
echo "Deployer has ADMIN_ROLE:"
~/.foundry/bin/cast call $SPLITTER "hasRole(bytes32,address)(bool)" "$ADMIN_ROLE" "$DEPLOYER" --rpc-url "$MAINNET_RPC_URL"
echo "Factory has ADMIN_ROLE:"
~/.foundry/bin/cast call $SPLITTER "hasRole(bytes32,address)(bool)" "$ADMIN_ROLE" "$FACTORY" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Checking DEFAULT_ADMIN_ROLE (0x00)..."
echo "Deployer has DEFAULT_ADMIN_ROLE:"
~/.foundry/bin/cast call $SPLITTER "hasRole(bytes32,address)(bool)" "0x0000000000000000000000000000000000000000000000000000000000000000" "$DEPLOYER" --rpc-url "$MAINNET_RPC_URL"
echo "Factory has DEFAULT_ADMIN_ROLE:"
~/.foundry/bin/cast call $SPLITTER "hasRole(bytes32,address)(bool)" "0x0000000000000000000000000000000000000000000000000000000000000000" "$FACTORY" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Role admin for ADMIN_ROLE ==="
~/.foundry/bin/cast call $SPLITTER "getRoleAdmin(bytes32)(bytes32)" "$ADMIN_ROLE" --rpc-url "$MAINNET_RPC_URL"
