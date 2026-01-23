#!/bin/bash
# Test ShutdownStakingV1 script on forked mainnet

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Testing StakingV1 Shutdown on Forked Mainnet ==="
echo ""

# Use public RPC if MAINNET_RPC_URL not set
RPC_URL="${MAINNET_RPC_URL:-https://eth.llamarpc.com}"
echo "Using RPC: $RPC_URL"
echo ""

cd "$PROJECT_ROOT"

# Step 1: Deploy StakingV2 on fork
echo "Step 1: Deploying StakingV2 on forked mainnet..."
echo "----------------------------------------"
~/.foundry/bin/forge script scripts/solidity/deploy/DeployStakingV2.s.sol \
    --rpc-url "$RPC_URL" \
    --fork-block-number latest \
    -vvv

echo ""
echo "Step 2: Extracting StakingV2 address from deployment..."
echo "----------------------------------------"
# TODO: Extract address from broadcast artifacts or logs
# For now, you'll need to manually update ShutdownStakingV1.s.sol with the deployed address

echo ""
echo "Step 3: Testing shutdown script on fork..."
echo "----------------------------------------"
~/.foundry/bin/forge script scripts/solidity/deploy/ShutdownStakingV1.s.sol \
    --rpc-url "$RPC_URL" \
    --fork-block-number latest \
    -vvv

echo ""
echo "=== Fork Test Complete ==="
echo ""
echo "IMPORTANT: This was a simulation only. No mainnet state was changed."
echo ""
echo "Next steps:"
echo "1. Review the output above for any errors"
echo "2. Update ShutdownStakingV1.s.sol with actual StakingV2 address"
echo "3. Run with --broadcast flag to execute on mainnet (ONLY after importing V1 deposits!)"
