#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

OLD_NFT="0x5f056911b9FC29f991039e4322b7755ccc9CbE9D"

echo "=== Reading Old NFT Settings ==="
echo "Contract: $OLD_NFT"
echo ""

echo "=== Basic Info ==="
echo "Name:"
~/.foundry/bin/cast call $OLD_NFT "name()(string)" --rpc-url "$MAINNET_RPC_URL"
echo "Symbol:"
~/.foundry/bin/cast call $OLD_NFT "symbol()(string)" --rpc-url "$MAINNET_RPC_URL"
echo "Total Supply:"
~/.foundry/bin/cast call $OLD_NFT "totalSupply()(uint256)" --rpc-url "$MAINNET_RPC_URL"
echo "Max Supply:"
~/.foundry/bin/cast call $OLD_NFT "maxSupply()(uint256)" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== URI Settings ==="
echo "Base URI:"
~/.foundry/bin/cast call $OLD_NFT "baseURI()(string)" --rpc-url "$MAINNET_RPC_URL"
echo "Contract URI:"
~/.foundry/bin/cast call $OLD_NFT "contractURI()(string)" --rpc-url "$MAINNET_RPC_URL" 2>/dev/null || echo "(not set)"

echo ""
echo "=== Transfer Validator (Creator Token) ==="
echo "Transfer Validator:"
~/.foundry/bin/cast call $OLD_NFT "getTransferValidator()(address)" --rpc-url "$MAINNET_RPC_URL"
echo "Security Policy:"
~/.foundry/bin/cast call $OLD_NFT "getSecurityPolicy()(uint8,uint8,uint8)" --rpc-url "$MAINNET_RPC_URL" 2>/dev/null || echo "(using default)"

echo ""
echo "=== Royalty Info ==="
echo "Royalty for tokenId 0, 1 ETH sale:"
~/.foundry/bin/cast call $OLD_NFT "royaltyInfo(uint256,uint256)(address,uint256)" 0 1000000000000000000 --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Role Members ==="
echo "DEFAULT_ADMIN_ROLE count:"
~/.foundry/bin/cast call $OLD_NFT "getRoleMemberCount(bytes32)(uint256)" "0x0000000000000000000000000000000000000000000000000000000000000000" --rpc-url "$MAINNET_RPC_URL"
MINTER_ROLE=$(~/.foundry/bin/cast keccak "MINTER_ROLE")
echo "MINTER_ROLE ($MINTER_ROLE) count:"
~/.foundry/bin/cast call $OLD_NFT "getRoleMemberCount(bytes32)(uint256)" "$MINTER_ROLE" --rpc-url "$MAINNET_RPC_URL"
DNA_ROLE=$(~/.foundry/bin/cast keccak "DNA_MODIFIER_ROLE")
echo "DNA_MODIFIER_ROLE ($DNA_ROLE) count:"
~/.foundry/bin/cast call $OLD_NFT "getRoleMemberCount(bytes32)(uint256)" "$DNA_ROLE" --rpc-url "$MAINNET_RPC_URL"

echo ""
echo "=== Done ==="
