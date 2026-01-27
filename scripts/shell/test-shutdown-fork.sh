#!/bin/bash
# Test ShutdownStakingV1 script on forked mainnet

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Testing StakingV1 Shutdown on Forked Mainnet ==="
echo ""

# Source .env if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Require MAINNET_RPC_URL from .env (no public RPC fallback)
if [ -z "$MAINNET_RPC_URL" ]; then
    echo "ERROR: MAINNET_RPC_URL not set in .env"
    exit 1
fi
RPC_URL="$MAINNET_RPC_URL"
echo "Using RPC: $RPC_URL"
echo ""

cd "$PROJECT_ROOT"

# Get latest block number from the RPC
echo "Fetching latest block number..."
BLOCK_NUMBER=$(~/.foundry/bin/cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "")
if [ -z "$BLOCK_NUMBER" ]; then
    echo "Warning: Could not fetch block number, running without fork-block-number"
    FORK_BLOCK_ARG=""
else
    echo "Using block number: $BLOCK_NUMBER"
    FORK_BLOCK_ARG="--fork-block-number $BLOCK_NUMBER"
fi
echo ""

# Step 1: Deploy StakingV2 on fork
echo "Step 1: Deploying StakingV2 on forked mainnet..."
echo "----------------------------------------"
~/.foundry/bin/forge script scripts/solidity/deploy/DeployStakingV2.s.sol \
    --rpc-url "$RPC_URL" \
    $FORK_BLOCK_ARG \
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
    $FORK_BLOCK_ARG \
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
