#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

NEW_NFT="0xdC75300bAbaC28BA2A28393D3494DeEeE452E361"

echo "=== Verifying New NFT Settings ==="
echo "Contract: $NEW_NFT"
echo ""

echo "=== Basic Info ==="
echo "Name:"
~/.foundry/bin/cast call $NEW_NFT "name()(string)" --rpc-url "$MAINNET_RPC_URL"
echo "Symbol:"
~/.foundry/bin/cast call $NEW_NFT "symbol()(string)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== URI Settings ==="
echo "Base URI:"
~/.foundry/bin/cast call $NEW_NFT "baseURI()(string)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Transfer Validator ==="
echo "Transfer Validator:"
~/.foundry/bin/cast call $NEW_NFT "getTransferValidator()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Royalty Info ==="
echo "Royalty for tokenId 0, 1 ETH sale:"
~/.foundry/bin/cast call $NEW_NFT "royaltyInfo(uint256,uint256)(address,uint256)" 0 1000000000000000000 --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Splitter ==="
echo "Royalty Splitter:"
~/.foundry/bin/cast call $NEW_NFT "royaltySplitter()(address)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Role Checks ==="
MINTER_ROLE=$(~/.foundry/bin/cast keccak "MINTER_ROLE")
DNA_ROLE=$(~/.foundry/bin/cast keccak "DNA_MODIFIER_ROLE")

echo "Manufacturer (0x5c8F...114) has DEFAULT_ADMIN_ROLE:"
~/.foundry/bin/cast call $NEW_NFT "hasRole(bytes32,address)(bool)" "0x0000000000000000000000000000000000000000000000000000000000000000" "0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114" --rpc-url "$MAINNET_RPC_URL"

echo "Manufacturer (0x5c8F...114) has MINTER_ROLE:"
~/.foundry/bin/cast call $NEW_NFT "hasRole(bytes32,address)(bool)" "$MINTER_ROLE" "0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114" --rpc-url "$MAINNET_RPC_URL"

echo "Extra minter (0xa14F...46BF) has MINTER_ROLE:"
~/.foundry/bin/cast call $NEW_NFT "hasRole(bytes32,address)(bool)" "$MINTER_ROLE" "0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF" --rpc-url "$MAINNET_RPC_URL"

echo "Extra address (0xa14F...46BF) has DNA_MODIFIER_ROLE:"
~/.foundry/bin/cast call $NEW_NFT "hasRole(bytes32,address)(bool)" "$DNA_ROLE" "0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Verification Complete ==="
