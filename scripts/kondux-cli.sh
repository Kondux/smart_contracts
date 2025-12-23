#!/usr/bin/env bash
#
# Kondux Smart Contracts CLI
# Unified interface for deployment, management, and operations
#
# Usage: ./scripts/kondux-cli.sh <command> [subcommand] [options]
#
# SAFETY: Default network is sepolia, dry-run is ON by default
# Use --mainnet and --broadcast to execute on mainnet
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
    export $(cat "$ROOT_DIR/.env" | grep -v '^#' | xargs)
fi

# Forge binary
FORGE="${FORGE_PATH:-forge}"

# Version
VERSION="1.0.0"

# =============================================================================
# Help Functions
# =============================================================================

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║         Kondux Smart Contracts CLI        ║"
    echo "║              v${VERSION}                        ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_usage() {
    print_banner
    cat << 'EOF'
USAGE
    kondux-cli.sh <command> [subcommand] [options]

DESCRIPTION
    Unified CLI for deploying, upgrading, and managing Kondux smart contracts.
    Supports multiple networks with safe defaults (Sepolia + dry-run).

EOF
    echo -e "${BOLD}COMMANDS${NC}"
    echo ""
    echo -e "  ${YELLOW}deploy${NC}         Deploy smart contracts"
    echo -e "  ${YELLOW}upgrade${NC}        Upgrade existing contracts"
    echo -e "  ${YELLOW}listing${NC}        Create OpenSea/Seaport listings"
    echo -e "  ${YELLOW}utility${NC}        Run utility operations"
    echo -e "  ${YELLOW}build${NC}          Build, test, and coverage"
    echo -e "  ${YELLOW}info${NC}           Display information"
    echo ""
    echo -e "${BOLD}GLOBAL OPTIONS${NC}"
    echo ""
    echo -e "  ${CYAN}Network (mutually exclusive):${NC}"
    echo "    --sepolia          Use Sepolia testnet ${DIM}(default)${NC}"
    echo "    --mainnet          Use Ethereum mainnet"
    echo "    --local            Use local Anvil/Hardhat node"
    echo ""
    echo -e "  ${CYAN}Execution:${NC}"
    echo "    --dry-run          Simulate without broadcasting ${DIM}(default)${NC}"
    echo "    --broadcast        Actually broadcast transactions"
    echo "    --verbose, -v      Enable verbose output"
    echo ""
    echo -e "  ${CYAN}Help:${NC}"
    echo "    --help, -h         Show this help message"
    echo "    --version          Show version number"
    echo ""
    echo -e "${BOLD}GETTING HELP FOR COMMANDS${NC}"
    echo ""
    echo "  kondux-cli.sh <command> --help    Show help for a specific command"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# Deploy factory (dry-run on Sepolia)${NC}"
    echo "  kondux-cli.sh deploy factory"
    echo ""
    echo "  ${DIM}# Deploy factory (live on Sepolia)${NC}"
    echo "  kondux-cli.sh deploy factory --broadcast"
    echo ""
    echo "  ${DIM}# Deploy factory (dry-run on Mainnet)${NC}"
    echo "  kondux-cli.sh deploy factory --mainnet"
    echo ""
    echo "  ${DIM}# Deploy factory (live on Mainnet - be careful!)${NC}"
    echo "  kondux-cli.sh deploy factory --mainnet --broadcast"
    echo ""
    echo -e "${BOLD}ENVIRONMENT VARIABLES${NC}"
    echo ""
    echo "  MAINNET_RPC_URL      Mainnet RPC endpoint"
    echo "  SEPOLIA_RPC_URL      Sepolia RPC endpoint"
    echo "  PROD_DEPLOYER_PK     Mainnet deployer private key"
    echo "  TEST_DEPLOYER_PK     Testnet deployer private key"
    echo "  ETHERSCAN_API_KEY    For contract verification"
    echo "  OPENSEA_API_KEY      For marketplace listings"
    echo ""
    echo -e "${BOLD}MORE INFO${NC}"
    echo ""
    echo "  Documentation:  docs/script-reorganization-plan.md"
    echo "  Config:         .env.example"
    echo ""
}

print_deploy_help() {
    print_banner
    cat << 'EOF'
COMMAND: deploy

DESCRIPTION
    Deploy Kondux smart contracts to the blockchain.

USAGE
    kondux-cli.sh deploy <subcommand> [options]

SUBCOMMANDS
EOF
    echo ""
    echo -e "  ${YELLOW}factory${NC}"
    echo "      Deploy KonduxBeaconFactory - the main factory contract that"
    echo "      creates beacon proxies for NFT collections."
    echo "      ${DIM}Script: DeployKonduxBeaconFactory.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}collection${NC}"
    echo "      Deploy a new NFT collection with integrated royalty splitter."
    echo "      Creates both the BeaconProxy NFT and RoyaltySplitter contracts."
    echo "      ${DIM}Script: DeployCollectionWithSplitter.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}implementation${NC}"
    echo "      Deploy a new implementation contract for beacon upgrades."
    echo "      Does NOT upgrade existing proxies (use 'upgrade' command)."
    echo "      ${DIM}Script: DeployKonduxImplementation.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}batch-minter${NC}"
    echo "      Deploy KonduxBatchMinter for efficient bulk minting operations."
    echo "      ${DIM}Script: DeployKonduxBatchMinter.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}splitter${NC}"
    echo "      Deploy a standalone RoyaltySplitter contract."
    echo "      ${DIM}Script: DeployRoyaltySplitter.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}helper${NC}"
    echo "      Deploy SeaportHelper for creating Seaport orders with royalties."
    echo "      ${DIM}Script: DeploySeaportHelper.s.sol${NC}"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# Deploy factory on Sepolia (dry-run)${NC}"
    echo "  kondux-cli.sh deploy factory"
    echo ""
    echo "  ${DIM}# Deploy collection on Mainnet (live)${NC}"
    echo "  kondux-cli.sh deploy collection --mainnet --broadcast"
    echo ""
}

print_upgrade_help() {
    print_banner
    cat << 'EOF'
COMMAND: upgrade

DESCRIPTION
    Upgrade existing Kondux smart contracts via beacon proxy pattern.

USAGE
    kondux-cli.sh upgrade <subcommand> [options]

SUBCOMMANDS
EOF
    echo ""
    echo -e "  ${YELLOW}implementation${NC}"
    echo "      Upgrade the beacon's implementation contract."
    echo "      All proxy contracts pointing to the beacon will use the new implementation."
    echo "      ${DIM}Script: UpgradeImplementation.s.sol${NC}"
    echo ""
    echo -e "${BOLD}UPGRADE PROCESS${NC}"
    echo ""
    echo "  1. Deploy new implementation:  kondux-cli.sh deploy implementation"
    echo "  2. Upgrade beacon:             kondux-cli.sh upgrade implementation"
    echo "  3. All proxies now use new implementation automatically"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# Dry-run upgrade on Sepolia${NC}"
    echo "  kondux-cli.sh upgrade implementation"
    echo ""
    echo "  ${DIM}# Live upgrade on Mainnet${NC}"
    echo "  kondux-cli.sh upgrade implementation --mainnet --broadcast"
    echo ""
}

print_listing_help() {
    print_banner
    cat << 'EOF'
COMMAND: listing

DESCRIPTION
    Create NFT listings on OpenSea via Seaport protocol.

USAGE
    kondux-cli.sh listing <subcommand> [args] [options]

SUBCOMMANDS
EOF
    echo ""
    echo -e "  ${YELLOW}create${NC} [token_id] [price_eth]"
    echo "      Create a listing via OpenSea API (JavaScript)."
    echo "      Uses EIP-712 signing and submits to OpenSea's order book."
    echo "      ${DIM}Script: util/listOnOpenSea.js${NC}"
    echo ""
    echo "      Arguments:"
    echo "        token_id   - Token ID to list (default: 2)"
    echo "        price_eth  - Price in ETH (default: 0.0001)"
    echo ""
    echo -e "  ${YELLOW}seaport${NC}"
    echo "      Create a Seaport order via Solidity script."
    echo "      Useful for custom order configurations."
    echo "      ${DIM}Script: CreateSeaportListing.s.sol${NC}"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# List token #5 at 0.1 ETH (dry-run)${NC}"
    echo "  kondux-cli.sh listing create 5 0.1"
    echo ""
    echo "  ${DIM}# Actually create the listing${NC}"
    echo "  kondux-cli.sh listing create 5 0.1 --broadcast"
    echo ""
}

print_utility_help() {
    print_banner
    cat << 'EOF'
COMMAND: utility

DESCRIPTION
    Run utility and maintenance operations.

USAGE
    kondux-cli.sh utility <subcommand> [options]

SUBCOMMANDS
EOF
    echo ""
    echo -e "  ${YELLOW}fix-policy${NC}"
    echo "      Fix Kondux security policy on the transfer validator."
    echo "      ${DIM}Script: FixKonduxSecurityPolicy.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}sweep-eth${NC}"
    echo "      Sweep accumulated ETH from the royalty splitter."
    echo "      Distributes royalties to configured recipients."
    echo "      ${DIM}Script: SweepSplitterETH.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}copy-settings${NC}"
    echo "      Copy NFT settings from one collection to another."
    echo "      ${DIM}Script: CopyNFTSettings.s.sol${NC}"
    echo ""
    echo -e "  ${YELLOW}extract-abis${NC}"
    echo "      Extract contract ABIs to JSON files for frontend use."
    echo "      ${DIM}Script: util/extractAbis.js${NC}"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# Extract ABIs (no network needed)${NC}"
    echo "  kondux-cli.sh utility extract-abis"
    echo ""
    echo "  ${DIM}# Sweep splitter on Mainnet${NC}"
    echo "  kondux-cli.sh utility sweep-eth --mainnet --broadcast"
    echo ""
}

print_build_help() {
    print_banner
    cat << 'EOF'
COMMAND: build

DESCRIPTION
    Build, test, and analyze smart contracts using Foundry.

USAGE
    kondux-cli.sh build <subcommand> [args]

SUBCOMMANDS
EOF
    echo ""
    echo -e "  ${YELLOW}compile${NC}"
    echo "      Compile all contracts using Forge."
    echo "      Equivalent to: forge build"
    echo ""
    echo -e "  ${YELLOW}test${NC} [args...]"
    echo "      Run the test suite."
    echo "      Additional arguments are passed to 'forge test'."
    echo "      Equivalent to: forge test -v [args...]"
    echo ""
    echo -e "  ${YELLOW}coverage${NC} [args...]"
    echo "      Generate test coverage report."
    echo "      Additional arguments are passed to 'forge coverage'."
    echo "      Equivalent to: forge coverage [args...]"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# Compile contracts${NC}"
    echo "  kondux-cli.sh build compile"
    echo ""
    echo "  ${DIM}# Run all tests${NC}"
    echo "  kondux-cli.sh build test"
    echo ""
    echo "  ${DIM}# Run specific test${NC}"
    echo "  kondux-cli.sh build test --match-test testMint"
    echo ""
    echo "  ${DIM}# Run tests with gas report${NC}"
    echo "  kondux-cli.sh build test --gas-report"
    echo ""
    echo "  ${DIM}# Generate coverage report${NC}"
    echo "  kondux-cli.sh build coverage"
    echo ""
}

print_info_help() {
    print_banner
    cat << 'EOF'
COMMAND: info

DESCRIPTION
    Display information about deployments and contracts.

USAGE
    kondux-cli.sh info <subcommand>

SUBCOMMANDS
EOF
    echo ""
    echo -e "  ${YELLOW}addresses${NC}"
    echo "      Show all deployed contract addresses for current deployment."
    echo "      Includes factory, beacon, collections, and Seaport contracts."
    echo ""
    echo -e "  ${YELLOW}gas${NC}"
    echo "      Run tests with gas reporting enabled."
    echo "      Shows gas costs for all contract functions."
    echo "      Equivalent to: forge test --gas-report"
    echo ""
    echo -e "${BOLD}EXAMPLES${NC}"
    echo ""
    echo "  ${DIM}# Show deployed addresses${NC}"
    echo "  kondux-cli.sh info addresses"
    echo ""
    echo "  ${DIM}# Show gas estimates${NC}"
    echo "  kondux-cli.sh info gas"
    echo ""
}

# =============================================================================
# Network Functions
# =============================================================================

get_network_settings() {
    local network="${1:-mainnet}"

    case "$network" in
        mainnet)
            RPC_URL="${MAINNET_RPC_URL}"
            PRIVATE_KEY="${PROD_DEPLOYER_PK}"
            CHAIN_ID=1
            ETHERSCAN_URL="https://etherscan.io"
            ;;
        sepolia)
            RPC_URL="${SEPOLIA_RPC_URL}"
            PRIVATE_KEY="${TEST_DEPLOYER_PK:-$PROD_DEPLOYER_PK}"
            CHAIN_ID=11155111
            ETHERSCAN_URL="https://sepolia.etherscan.io"
            ;;
        local)
            RPC_URL="${LOCAL_RPC_URL:-http://localhost:8545}"
            PRIVATE_KEY="${LOCAL_PK:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
            CHAIN_ID=31337
            ETHERSCAN_URL=""
            ;;
        *)
            echo -e "${RED}Error: Unknown network '$network'${NC}"
            exit 1
            ;;
    esac
}

build_forge_cmd() {
    local script="$1"
    local broadcast="${2:-false}"

    local cmd="$FORGE script $script --rpc-url $RPC_URL --private-key $PRIVATE_KEY"

    if [ "$broadcast" = "true" ]; then
        cmd="$cmd --broadcast"
        if [ -n "$ETHERSCAN_API_KEY" ] && [ "$NETWORK" != "local" ]; then
            cmd="$cmd --verify --etherscan-api-key $ETHERSCAN_API_KEY"
        fi
    fi

    if [ "$VERBOSE" = "true" ]; then
        cmd="$cmd -vvvv"
    else
        cmd="$cmd -v"
    fi

    echo "$cmd"
}

print_mode() {
    if [ "$BROADCAST" = "true" ]; then
        echo -e "${RED}[LIVE] Broadcasting to $NETWORK${NC}"
    else
        echo -e "${GREEN}[DRY-RUN] Simulating on $NETWORK (use --broadcast to execute)${NC}"
    fi
    echo ""
}

# =============================================================================
# Command Functions
# =============================================================================

cmd_deploy() {
    local subcommand="$1"
    shift

    if [ "$subcommand" = "--help" ] || [ "$subcommand" = "-h" ] || [ -z "$subcommand" ]; then
        print_deploy_help
        exit 0
    fi

    print_mode

    case "$subcommand" in
        factory)
            echo -e "${GREEN}Deploying KonduxBeaconFactory...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/deploy/DeployKonduxBeaconFactory.s.sol:DeployKonduxBeaconFactoryScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        collection)
            echo -e "${GREEN}Deploying Collection with Splitter...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/deploy/DeployCollectionWithSplitter.s.sol:DeployCollectionWithSplitterScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        implementation)
            echo -e "${GREEN}Deploying new Implementation...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/deploy/DeployKonduxImplementation.s.sol:DeployKonduxImplementationScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        batch-minter)
            echo -e "${GREEN}Deploying KonduxBatchMinter...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/deploy/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        splitter)
            echo -e "${GREEN}Deploying Royalty Splitter...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/deploy/DeployRoyaltySplitter.s.sol:DeployRoyaltySplitterScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        helper)
            echo -e "${GREEN}Deploying SeaportHelper...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/deploy/DeploySeaportHelper.s.sol:DeploySeaportHelperScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        *)
            echo -e "${RED}Unknown deploy subcommand: $subcommand${NC}"
            echo ""
            echo "Available subcommands: factory, collection, implementation, batch-minter, splitter, helper"
            echo "Run 'kondux-cli.sh deploy --help' for details"
            exit 1
            ;;
    esac
}

cmd_upgrade() {
    local subcommand="$1"
    shift

    if [ "$subcommand" = "--help" ] || [ "$subcommand" = "-h" ] || [ -z "$subcommand" ]; then
        print_upgrade_help
        exit 0
    fi

    print_mode

    case "$subcommand" in
        implementation)
            echo -e "${GREEN}Upgrading Implementation...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/upgrade/UpgradeImplementation.s.sol:UpgradeImplementationScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        *)
            echo -e "${RED}Unknown upgrade subcommand: $subcommand${NC}"
            echo ""
            echo "Available subcommands: implementation"
            echo "Run 'kondux-cli.sh upgrade --help' for details"
            exit 1
            ;;
    esac
}

cmd_listing() {
    local subcommand="$1"
    shift

    if [ "$subcommand" = "--help" ] || [ "$subcommand" = "-h" ] || [ -z "$subcommand" ]; then
        print_listing_help
        exit 0
    fi

    case "$subcommand" in
        create)
            local token_id="${1:-2}"
            local price="${2:-0.0001}"
            print_mode
            if [ "$BROADCAST" != "true" ]; then
                echo -e "${YELLOW}[DRY-RUN] Would create listing for token $token_id at $price ETH${NC}"
                echo "Command: node $SCRIPT_DIR/util/listOnOpenSea.js $token_id $price"
            else
                echo -e "${GREEN}Creating OpenSea listing for token $token_id at $price ETH...${NC}"
                node "$SCRIPT_DIR/util/listOnOpenSea.js" "$token_id" "$price"
            fi
            ;;
        seaport)
            print_mode
            echo -e "${GREEN}Creating Seaport listing...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/seaport/CreateSeaportListing.s.sol:CreateSeaportListingScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        *)
            echo -e "${RED}Unknown listing subcommand: $subcommand${NC}"
            echo ""
            echo "Available subcommands: create, seaport"
            echo "Run 'kondux-cli.sh listing --help' for details"
            exit 1
            ;;
    esac
}

cmd_utility() {
    local subcommand="$1"
    shift

    if [ "$subcommand" = "--help" ] || [ "$subcommand" = "-h" ] || [ -z "$subcommand" ]; then
        print_utility_help
        exit 0
    fi

    case "$subcommand" in
        fix-policy)
            print_mode
            echo -e "${GREEN}Fixing Kondux Security Policy...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/utility/FixKonduxSecurityPolicy.s.sol:FixKonduxSecurityPolicyScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        sweep-eth)
            print_mode
            echo -e "${GREEN}Sweeping Splitter ETH...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/utility/SweepSplitterETH.s.sol:SweepSplitterETHScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        copy-settings)
            print_mode
            echo -e "${GREEN}Copying NFT Settings...${NC}"
            local cmd=$(build_forge_cmd "scripts/solidity/utility/CopyNFTSettings.s.sol:CopyNFTSettingsScript" "$BROADCAST")
            echo "Running: $cmd"
            eval $cmd
            ;;
        extract-abis)
            echo -e "${GREEN}Extracting ABIs...${NC}"
            node "$SCRIPT_DIR/util/extractAbis.js"
            ;;
        *)
            echo -e "${RED}Unknown utility subcommand: $subcommand${NC}"
            echo ""
            echo "Available subcommands: fix-policy, sweep-eth, copy-settings, extract-abis"
            echo "Run 'kondux-cli.sh utility --help' for details"
            exit 1
            ;;
    esac
}

cmd_build() {
    local subcommand="$1"
    shift

    if [ "$subcommand" = "--help" ] || [ "$subcommand" = "-h" ] || [ -z "$subcommand" ]; then
        print_build_help
        exit 0
    fi

    case "$subcommand" in
        compile)
            echo -e "${GREEN}Compiling contracts...${NC}"
            $FORGE build
            ;;
        test)
            echo -e "${GREEN}Running tests...${NC}"
            $FORGE test -v "$@"
            ;;
        coverage)
            echo -e "${GREEN}Running coverage...${NC}"
            $FORGE coverage "$@"
            ;;
        *)
            echo -e "${RED}Unknown build subcommand: $subcommand${NC}"
            echo ""
            echo "Available subcommands: compile, test, coverage"
            echo "Run 'kondux-cli.sh build --help' for details"
            exit 1
            ;;
    esac
}

cmd_info() {
    local subcommand="$1"
    shift

    if [ "$subcommand" = "--help" ] || [ "$subcommand" = "-h" ] || [ -z "$subcommand" ]; then
        print_info_help
        exit 0
    fi

    case "$subcommand" in
        addresses)
            echo -e "${GREEN}Deployed Contract Addresses${NC}"
            echo ""
            echo -e "${YELLOW}Core Infrastructure:${NC}"
            echo "  KonduxBeaconFactory:    0xa265a01205f304F2652277AaC924AB56D2e0Cf77"
            echo "  UpgradeableBeacon:      0x0aeD0fA92bCB03F7a37ad80D71AD181117B91F63"
            echo "  KonduxImplementation:   0xeAfB6E3Ecc6676D3D7ac16F15F33E2B56C74af49"
            echo ""
            echo -e "${YELLOW}Collections:${NC}"
            echo "  Kondux Test V2:         0x167a45aaC7a4512089eC6d401547351d7c73e66F"
            echo "  Collection Splitter:    0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8"
            echo ""
            echo -e "${YELLOW}Seaport Infrastructure:${NC}"
            echo "  Seaport 1.6:            0x0000000000000068F116a894984e2DB1123eB395"
            echo "  OpenSea Conduit:        0x1E0049783F008A0085193E00003D00cd54003c71"
            echo "  SeaportHelper:          0x92bC05d397Fc5d2E18d4d2DAf7EA8f60f7d67a1F"
            echo ""
            echo -e "${YELLOW}Transfer Validator:${NC}"
            echo "  CreatorTokenTransferValidator: 0x721C00182a990771244d7A71B9FA2ea789A3b433"
            ;;
        gas)
            echo -e "${GREEN}Running gas estimates...${NC}"
            $FORGE test --gas-report
            ;;
        *)
            echo -e "${RED}Unknown info subcommand: $subcommand${NC}"
            echo ""
            echo "Available subcommands: addresses, gas"
            echo "Run 'kondux-cli.sh info --help' for details"
            exit 1
            ;;
    esac
}

# =============================================================================
# Main Entry Point
# =============================================================================

# DEFAULTS: sepolia network, dry-run mode (safe by default)
NETWORK="sepolia"
BROADCAST="false"
VERBOSE="false"

# Parse global options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mainnet)
            NETWORK="mainnet"
            shift
            ;;
        --sepolia)
            NETWORK="sepolia"
            shift
            ;;
        --local)
            NETWORK="local"
            shift
            ;;
        --broadcast)
            BROADCAST="true"
            shift
            ;;
        --dry-run)
            BROADCAST="false"
            shift
            ;;
        --verbose|-v)
            VERBOSE="true"
            shift
            ;;
        --version)
            echo "kondux-cli.sh v${VERSION}"
            exit 0
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Get command
COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
    print_usage
    exit 1
fi
shift

# Initialize network settings
get_network_settings "$NETWORK"

# Execute command
case "$COMMAND" in
    deploy)
        cmd_deploy "$@"
        ;;
    upgrade)
        cmd_upgrade "$@"
        ;;
    listing)
        cmd_listing "$@"
        ;;
    utility)
        cmd_utility "$@"
        ;;
    build)
        cmd_build "$@"
        ;;
    info)
        cmd_info "$@"
        ;;
    help)
        # Allow 'kondux-cli.sh help deploy' syntax
        if [ -n "$1" ]; then
            case "$1" in
                deploy) print_deploy_help ;;
                upgrade) print_upgrade_help ;;
                listing) print_listing_help ;;
                utility) print_utility_help ;;
                build) print_build_help ;;
                info) print_info_help ;;
                *) print_usage ;;
            esac
        else
            print_usage
        fi
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo ""
        echo "Available commands: deploy, upgrade, listing, utility, build, info"
        echo "Run 'kondux-cli.sh --help' for usage information"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
