#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

FACTORY="0xa265a01205f304F2652277AaC924AB56D2e0Cf77"
SPLITTER="0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8"

echo "=== Fixing Splitter Cuts ==="
echo "Setting: manufacturer=500 (5%), partner=0 (0%), creator=500 (5%)"
echo "Total: 10%"
echo ""

~/.foundry/bin/cast send $FACTORY \
  "setCutsOnSplitter(address,uint96,uint96,uint96)" \
  $SPLITTER 500 0 500 \
  --private-key "$PROD_DEPLOYER_PK" \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verifying New Cuts ==="
echo "Manufacturer cut (expect 500):"
~/.foundry/bin/cast call $SPLITTER "manufacturerCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo "Partner cut (expect 0):"
~/.foundry/bin/cast call $SPLITTER "partnerCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
echo "Creator cut (expect 500):"
~/.foundry/bin/cast call $SPLITTER "defaultCreatorCutBP()(uint96)" --rpc-url "$MAINNET_RPC_URL"
