#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

COLLECTION="0x167a45aaC7a4512089eC6d401547351d7c73e66F"
SPLITTER="0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8"
SEAPORT="0x0000000000000068F116a894984e2DB1123eB395"
CONDUIT="0x1E0049783F008A0085193E00003D00cd54003c71"

echo "=== Fixing New Collection Security & Royalty ==="
echo "Collection: $COLLECTION"
echo "Splitter: $SPLITTER"
echo ""

echo "1. Setting default security policy (whitelist Seaport, level 4)..."
~/.foundry/bin/cast send $COLLECTION \
  "setToDefaultSecurityPolicy()" \
  --private-key "$PROD_DEPLOYER_PK" \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "2. Adding OpenSea conduit to whitelist..."
~/.foundry/bin/cast send $COLLECTION \
  "addAccountsToWhitelist(address[])" "[$CONDUIT]" \
  --private-key "$PROD_DEPLOYER_PK" \
  --rpc-url "$MAINNET_RPC_URL"

# Note: Keeping default 10% royalty as per user request
# To change royalty, uncomment and adjust:
# echo ""
# echo "3. Setting royalty splits to X%..."
# ~/.foundry/bin/cast send $COLLECTION \
#   "setRoyaltySplits(uint96,uint96,uint96)" 200 150 150 \
#   --private-key "$PROD_DEPLOYER_PK" \
#   --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verifying Configuration ==="
echo "ERC2981 royaltyInfo (for 1 ETH sale):"
~/.foundry/bin/cast call $COLLECTION \
  "royaltyInfo(uint256,uint256)(address,uint256)" 0 1000000000000000000 \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "Transfer security level:"
~/.foundry/bin/cast call $COLLECTION \
  "getTransferValidator()(address)" \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Done ==="
