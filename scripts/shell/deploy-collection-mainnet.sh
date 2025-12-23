#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

echo "=== Deploying New NFT Collection with Atomic Distribution ==="
echo ""
echo "This will deploy:"
echo "  1. KonduxImplementation (logic contract)"
echo "  2. KonduxBeaconFactory (for upgradeable clones)"
echo "  3. New NFT Collection (BeaconProxy)"
echo "  4. KonduxRoyaltySplitter (atomic distribution)"
echo ""

# Configuration - UPDATE THESE AS NEEDED
export COLLECTION_NAME="Kondux kNFT"
export COLLECTION_SYMBOL="kNFT"
export MAX_SUPPLY=0  # 0 = unlimited

# Royalty configuration (in basis points, 100 = 1%)
export MANUFACTURER_CUT_BP=400  # 4% - Kondux treasury
export PARTNER_CUT_BP=300       # 3% - Partner/collection owner
export CREATOR_CUT_BP=300       # 3% - Original minter
# Total: 10% (matches the existing setup)

# Wallet addresses (loaded from .env or set here)
# COLLECTION_ADMIN: Who controls the collection (minting, DNA, etc.)
# PARTNER_WALLET: Receives partner royalty share
# DEFAULT_CREATOR_WALLET: Fallback for unregistered creators

# Use the same wallets as the existing splitter:
# Manufacturer: 0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114
# Partner: 0x4936167DAE4160E5556D9294F2C78675659a3B63
# Default Creator: 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2

export PARTNER_WALLET="0x4936167DAE4160E5556D9294F2C78675659a3B63"
export DEFAULT_CREATOR_WALLET="0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"
# COLLECTION_ADMIN will be set to deployer by default

# Skip verification during deployment (verify manually later)
# Override VERIFY from .env to skip on-chain verification
unset VERIFY
export RUN_SMOKE_TEST=true

# Run the deployment
~/.foundry/bin/forge script script/DeployCollectionWithSplitter.s.sol:DeployCollectionWithSplitterScript \
    --rpc-url "$MAINNET_RPC_URL" \
    --broadcast \
    -vvv

echo ""
echo "=== Deployment Complete ==="
echo "Save the addresses from the output above!"
echo ""
echo "Next steps:"
echo "1. Verify contracts on Etherscan (optional)"
echo "2. Set up OpenSea royalties to point to the new splitter"
echo "3. Configure the collection (base URI, security policy, etc.)"
