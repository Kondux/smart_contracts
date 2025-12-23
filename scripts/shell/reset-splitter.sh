#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

COLLECTION="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"
SPLITTER="0xEA4F2710def06Ee87acDC8d449A198A08E650B64"

echo "=== Setting Splitter as ERC2981 Receiver ==="
~/.foundry/bin/cast send $COLLECTION \
  "setRoyaltySplitter(address)" \
  $SPLITTER \
  --private-key "$PROD_DEPLOYER_PK" \
  --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verifying ==="
~/.foundry/bin/cast call $COLLECTION \
  "royaltyInfo(uint256,uint256)(address,uint256)" 1 1000000000000000 \
  --rpc-url "$MAINNET_RPC_URL"
