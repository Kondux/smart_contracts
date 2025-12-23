#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

OLD_NFT="0x5f056911b9FC29f991039e4322b7755ccc9CbE9D"

echo "=== Role Members from Old NFT ==="

DEFAULT_ADMIN="0x0000000000000000000000000000000000000000000000000000000000000000"
MINTER_ROLE=$(~/.foundry/bin/cast keccak "MINTER_ROLE")
DNA_ROLE=$(~/.foundry/bin/cast keccak "DNA_MODIFIER_ROLE")

echo ""
echo "DEFAULT_ADMIN_ROLE members:"
for i in 0 1; do
    addr=$(~/.foundry/bin/cast call $OLD_NFT "getRoleMember(bytes32,uint256)(address)" "$DEFAULT_ADMIN" $i --rpc-url "$MAINNET_RPC_URL" 2>/dev/null)
    if [ ! -z "$addr" ] && [ "$addr" != "0x0000000000000000000000000000000000000000" ]; then
        echo "  [$i]: $addr"
    fi
done

echo ""
echo "MINTER_ROLE members:"
for i in 0 1 2; do
    addr=$(~/.foundry/bin/cast call $OLD_NFT "getRoleMember(bytes32,uint256)(address)" "$MINTER_ROLE" $i --rpc-url "$MAINNET_RPC_URL" 2>/dev/null)
    if [ ! -z "$addr" ] && [ "$addr" != "0x0000000000000000000000000000000000000000" ]; then
        echo "  [$i]: $addr"
    fi
done

echo ""
echo "DNA_MODIFIER_ROLE members:"
for i in 0 1; do
    addr=$(~/.foundry/bin/cast call $OLD_NFT "getRoleMember(bytes32,uint256)(address)" "$DNA_ROLE" $i --rpc-url "$MAINNET_RPC_URL" 2>/dev/null)
    if [ ! -z "$addr" ] && [ "$addr" != "0x0000000000000000000000000000000000000000" ]; then
        echo "  [$i]: $addr"
    fi
done

echo ""
echo "=== Done ==="
