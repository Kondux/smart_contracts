#
# Kondux Smart Contracts CLI (PowerShell)
# Unified interface for deployment, management, and operations
#
# Usage: .\scripts\kondux-cli.ps1 <command> [options]
#
# SAFETY: Default network is sepolia, dry-run is ON by default
# Use -Mainnet and -Broadcast to execute on mainnet
#

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$Subcommand,

    [Parameter(Position=2, ValueFromRemainingArguments)]
    [string[]]$Arguments,

    [switch]$Mainnet,
    [switch]$Sepolia,
    [switch]$Local,
    [switch]$Broadcast,
    [switch]$DryRun,
    [Alias("v")]
    [switch]$VerboseOutput,
    [switch]$Help,
    [switch]$Version
)

$ErrorActionPreference = "Stop"

# Colors
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Blue = "Cyan"
$White = "White"
$Gray = "DarkGray"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# Version
$CLI_VERSION = "1.0.0"

# Load .env file if exists
$EnvFile = Join-Path $RootDir ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
}

# =============================================================================
# Help Functions
# =============================================================================

function Write-Banner {
    Write-Host ""
    Write-Host "+==============================================+" -ForegroundColor $Blue
    Write-Host "|         Kondux Smart Contracts CLI           |" -ForegroundColor $Blue
    Write-Host "|              v$CLI_VERSION                         |" -ForegroundColor $Blue
    Write-Host "+==============================================+" -ForegroundColor $Blue
    Write-Host ""
}

function Write-Usage {
    Write-Banner
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 <command> [subcommand] [options]"
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Unified CLI for deploying, upgrading, and managing Kondux smart contracts."
    Write-Host "    Supports multiple networks with safe defaults (Sepolia + dry-run)."
    Write-Host ""
    Write-Host "COMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  deploy" -ForegroundColor $Yellow -NoNewline; Write-Host "         Deploy smart contracts"
    Write-Host "  upgrade" -ForegroundColor $Yellow -NoNewline; Write-Host "        Upgrade existing contracts"
    Write-Host "  listing" -ForegroundColor $Yellow -NoNewline; Write-Host "        Create OpenSea/Seaport listings"
    Write-Host "  utility" -ForegroundColor $Yellow -NoNewline; Write-Host "        Run utility operations"
    Write-Host "  build" -ForegroundColor $Yellow -NoNewline; Write-Host "          Build, test, and coverage"
    Write-Host "  info" -ForegroundColor $Yellow -NoNewline; Write-Host "           Display information"
    Write-Host ""
    Write-Host "GLOBAL OPTIONS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  Network (mutually exclusive):" -ForegroundColor $Blue
    Write-Host "    -Sepolia           Use Sepolia testnet " -NoNewline; Write-Host "(default)" -ForegroundColor $Gray
    Write-Host "    -Mainnet           Use Ethereum mainnet"
    Write-Host "    -Local             Use local Anvil/Hardhat node"
    Write-Host ""
    Write-Host "  Execution:" -ForegroundColor $Blue
    Write-Host "    -DryRun            Simulate without broadcasting " -NoNewline; Write-Host "(default)" -ForegroundColor $Gray
    Write-Host "    -Broadcast         Actually broadcast transactions"
    Write-Host "    -VerboseOutput, -v Enable verbose output"
    Write-Host ""
    Write-Host "  Help:" -ForegroundColor $Blue
    Write-Host "    -Help              Show this help message"
    Write-Host "    -Version           Show version number"
    Write-Host ""
    Write-Host "GETTING HELP FOR COMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  .\kondux-cli.ps1 <command> -Help    Show help for a specific command"
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  # Deploy factory (dry-run on Sepolia)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 deploy factory"
    Write-Host ""
    Write-Host "  # Deploy factory (live on Sepolia)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 deploy factory -Broadcast"
    Write-Host ""
    Write-Host "  # Deploy factory (dry-run on Mainnet)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 deploy factory -Mainnet"
    Write-Host ""
    Write-Host "  # Deploy factory (live on Mainnet - be careful!)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 deploy factory -Mainnet -Broadcast"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  MAINNET_RPC_URL      Mainnet RPC endpoint"
    Write-Host "  SEPOLIA_RPC_URL      Sepolia RPC endpoint"
    Write-Host "  PROD_DEPLOYER_PK     Mainnet deployer private key"
    Write-Host "  TEST_DEPLOYER_PK     Testnet deployer private key"
    Write-Host "  ETHERSCAN_API_KEY    For contract verification"
    Write-Host "  OPENSEA_API_KEY      For marketplace listings"
    Write-Host ""
    Write-Host "MORE INFO" -ForegroundColor $White
    Write-Host ""
    Write-Host "  Documentation:  docs/script-reorganization-plan.md"
    Write-Host "  Config:         .env.example"
    Write-Host ""
}

function Write-DeployHelp {
    Write-Banner
    Write-Host "COMMAND: deploy" -ForegroundColor $White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Deploy Kondux smart contracts to the blockchain."
    Write-Host ""
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 deploy <subcommand> [options]"
    Write-Host ""
    Write-Host "SUBCOMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  factory" -ForegroundColor $Yellow
    Write-Host "      Deploy KonduxBeaconFactory - the main factory contract that"
    Write-Host "      creates beacon proxies for NFT collections."
    Write-Host "      Script: DeployKonduxBeaconFactory.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  collection" -ForegroundColor $Yellow
    Write-Host "      Deploy a new NFT collection with integrated royalty splitter."
    Write-Host "      Creates both the BeaconProxy NFT and RoyaltySplitter contracts."
    Write-Host "      Script: DeployCollectionWithSplitter.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  implementation" -ForegroundColor $Yellow
    Write-Host "      Deploy a new implementation contract for beacon upgrades."
    Write-Host "      Does NOT upgrade existing proxies (use 'upgrade' command)."
    Write-Host "      Script: DeployKonduxImplementation.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  batch-minter" -ForegroundColor $Yellow
    Write-Host "      Deploy KonduxBatchMinter for efficient bulk minting operations."
    Write-Host "      Script: DeployKonduxBatchMinter.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  splitter" -ForegroundColor $Yellow
    Write-Host "      Deploy a standalone RoyaltySplitter contract."
    Write-Host "      Script: DeployRoyaltySplitter.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  helper" -ForegroundColor $Yellow
    Write-Host "      Deploy SeaportHelper for creating Seaport orders with royalties."
    Write-Host "      Script: DeploySeaportHelper.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  # Deploy factory on Sepolia (dry-run)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 deploy factory"
    Write-Host ""
    Write-Host "  # Deploy collection on Mainnet (live)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 deploy collection -Mainnet -Broadcast"
    Write-Host ""
}

function Write-UpgradeHelp {
    Write-Banner
    Write-Host "COMMAND: upgrade" -ForegroundColor $White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Upgrade existing Kondux smart contracts via beacon proxy pattern."
    Write-Host ""
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 upgrade <subcommand> [options]"
    Write-Host ""
    Write-Host "SUBCOMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  implementation" -ForegroundColor $Yellow
    Write-Host "      Upgrade the beacon's implementation contract."
    Write-Host "      All proxy contracts pointing to the beacon will use the new implementation."
    Write-Host "      Script: UpgradeImplementation.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "UPGRADE PROCESS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  1. Deploy new implementation:  .\kondux-cli.ps1 deploy implementation"
    Write-Host "  2. Upgrade beacon:             .\kondux-cli.ps1 upgrade implementation"
    Write-Host "  3. All proxies now use new implementation automatically"
    Write-Host ""
}

function Write-ListingHelp {
    Write-Banner
    Write-Host "COMMAND: listing" -ForegroundColor $White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Create NFT listings on OpenSea via Seaport protocol."
    Write-Host ""
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 listing <subcommand> [args] [options]"
    Write-Host ""
    Write-Host "SUBCOMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  create" -ForegroundColor $Yellow -NoNewline; Write-Host " [token_id] [price_eth]"
    Write-Host "      Create a listing via OpenSea API (JavaScript)."
    Write-Host "      Uses EIP-712 signing and submits to OpenSea's order book."
    Write-Host "      Script: util/listOnOpenSea.js" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "      Arguments:"
    Write-Host "        token_id   - Token ID to list (default: 2)"
    Write-Host "        price_eth  - Price in ETH (default: 0.0001)"
    Write-Host ""
    Write-Host "  seaport" -ForegroundColor $Yellow
    Write-Host "      Create a Seaport order via Solidity script."
    Write-Host "      Script: CreateSeaportListing.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  # List token #5 at 0.1 ETH (dry-run)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 listing create 5 0.1"
    Write-Host ""
    Write-Host "  # Actually create the listing" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 listing create 5 0.1 -Broadcast"
    Write-Host ""
}

function Write-UtilityHelp {
    Write-Banner
    Write-Host "COMMAND: utility" -ForegroundColor $White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Run utility and maintenance operations."
    Write-Host ""
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 utility <subcommand> [options]"
    Write-Host ""
    Write-Host "SUBCOMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  fix-policy" -ForegroundColor $Yellow
    Write-Host "      Fix Kondux security policy on the transfer validator."
    Write-Host "      Script: FixKonduxSecurityPolicy.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  sweep-eth" -ForegroundColor $Yellow
    Write-Host "      Sweep accumulated ETH from the royalty splitter."
    Write-Host "      Script: SweepSplitterETH.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  copy-settings" -ForegroundColor $Yellow
    Write-Host "      Copy NFT settings from one collection to another."
    Write-Host "      Script: CopyNFTSettings.s.sol" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "  extract-abis" -ForegroundColor $Yellow
    Write-Host "      Extract contract ABIs to JSON files for frontend use."
    Write-Host "      Script: util/extractAbis.js" -ForegroundColor $Gray
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  # Extract ABIs (no network needed)" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 utility extract-abis"
    Write-Host ""
    Write-Host "  # Sweep splitter on Mainnet" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 utility sweep-eth -Mainnet -Broadcast"
    Write-Host ""
}

function Write-BuildHelp {
    Write-Banner
    Write-Host "COMMAND: build" -ForegroundColor $White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Build, test, and analyze smart contracts using Foundry."
    Write-Host ""
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 build <subcommand> [args]"
    Write-Host ""
    Write-Host "SUBCOMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  compile" -ForegroundColor $Yellow
    Write-Host "      Compile all contracts using Forge."
    Write-Host "      Equivalent to: forge build"
    Write-Host ""
    Write-Host "  test" -ForegroundColor $Yellow -NoNewline; Write-Host " [args...]"
    Write-Host "      Run the test suite."
    Write-Host "      Equivalent to: forge test -v [args...]"
    Write-Host ""
    Write-Host "  coverage" -ForegroundColor $Yellow -NoNewline; Write-Host " [args...]"
    Write-Host "      Generate test coverage report."
    Write-Host "      Equivalent to: forge coverage [args...]"
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  # Compile contracts" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 build compile"
    Write-Host ""
    Write-Host "  # Run all tests" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 build test"
    Write-Host ""
    Write-Host "  # Run specific test" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 build test --match-test testMint"
    Write-Host ""
}

function Write-InfoHelp {
    Write-Banner
    Write-Host "COMMAND: info" -ForegroundColor $White
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor $White
    Write-Host "    Display information about deployments and contracts."
    Write-Host ""
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux-cli.ps1 info <subcommand>"
    Write-Host ""
    Write-Host "SUBCOMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  addresses" -ForegroundColor $Yellow
    Write-Host "      Show all deployed contract addresses."
    Write-Host ""
    Write-Host "  gas" -ForegroundColor $Yellow
    Write-Host "      Run tests with gas reporting enabled."
    Write-Host "      Equivalent to: forge test --gas-report"
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host ""
    Write-Host "  # Show deployed addresses" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 info addresses"
    Write-Host ""
    Write-Host "  # Show gas estimates" -ForegroundColor $Gray
    Write-Host "  .\kondux-cli.ps1 info gas"
    Write-Host ""
}

# =============================================================================
# Network Functions
# =============================================================================

function Get-NetworkSettings {
    param([string]$NetworkName)

    $settings = @{}

    switch ($NetworkName) {
        "mainnet" {
            $settings.RpcUrl = $env:MAINNET_RPC_URL
            $settings.PrivateKey = $env:PROD_DEPLOYER_PK
            $settings.ChainId = 1
        }
        "sepolia" {
            $settings.RpcUrl = $env:SEPOLIA_RPC_URL
            $settings.PrivateKey = if ($env:TEST_DEPLOYER_PK) { $env:TEST_DEPLOYER_PK } else { $env:PROD_DEPLOYER_PK }
            $settings.ChainId = 11155111
        }
        "local" {
            $settings.RpcUrl = if ($env:LOCAL_RPC_URL) { $env:LOCAL_RPC_URL } else { "http://localhost:8545" }
            $settings.PrivateKey = if ($env:LOCAL_PK) { $env:LOCAL_PK } else { "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" }
            $settings.ChainId = 31337
        }
        default {
            Write-Host "Error: Unknown network '$NetworkName'" -ForegroundColor $Red
            exit 1
        }
    }

    return $settings
}

function Build-ForgeCmd {
    param(
        [string]$Script,
        [hashtable]$NetworkSettings,
        [bool]$DoBroadcast
    )

    $cmd = "forge script $Script --rpc-url $($NetworkSettings.RpcUrl) --private-key $($NetworkSettings.PrivateKey)"

    if ($DoBroadcast) {
        $cmd += " --broadcast"
        if ($env:ETHERSCAN_API_KEY -and $script:NetworkName -ne "local") {
            $cmd += " --verify --etherscan-api-key $env:ETHERSCAN_API_KEY"
        }
    }

    if ($VerboseOutput) {
        $cmd += " -vvvv"
    } else {
        $cmd += " -v"
    }

    return $cmd
}

function Write-ExecutionMode {
    param([bool]$DoBroadcast, [string]$NetworkName)

    if ($DoBroadcast) {
        Write-Host "[LIVE] Broadcasting to $NetworkName" -ForegroundColor $Red
    } else {
        Write-Host "[DRY-RUN] Simulating on $NetworkName (use -Broadcast to execute)" -ForegroundColor $Green
    }
    Write-Host ""
}

# =============================================================================
# Command Functions
# =============================================================================

function Invoke-Deploy {
    param([string]$Sub, [hashtable]$Settings, [bool]$DoBroadcast, [string]$NetworkName)

    if ($Sub -eq "-Help" -or -not $Sub) {
        Write-DeployHelp
        return
    }

    Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName

    switch ($Sub) {
        "factory" {
            Write-Host "Deploying KonduxBeaconFactory..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/deploy/DeployKonduxBeaconFactory.s.sol:DeployKonduxBeaconFactoryScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "collection" {
            Write-Host "Deploying Collection with Splitter..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/deploy/DeployCollectionWithSplitter.s.sol:DeployCollectionWithSplitterScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "implementation" {
            Write-Host "Deploying new Implementation..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/deploy/DeployKonduxImplementation.s.sol:DeployKonduxImplementationScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "batch-minter" {
            Write-Host "Deploying KonduxBatchMinter..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/deploy/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "splitter" {
            Write-Host "Deploying Royalty Splitter..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/deploy/DeployRoyaltySplitter.s.sol:DeployRoyaltySplitterScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "helper" {
            Write-Host "Deploying SeaportHelper..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/deploy/DeploySeaportHelper.s.sol:DeploySeaportHelperScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        default {
            Write-Host "Unknown deploy subcommand: $Sub" -ForegroundColor $Red
            Write-Host ""
            Write-Host "Available: factory, collection, implementation, batch-minter, splitter, helper"
            Write-Host "Run '.\kondux-cli.ps1 deploy -Help' for details"
            exit 1
        }
    }
}

function Invoke-Upgrade {
    param([string]$Sub, [hashtable]$Settings, [bool]$DoBroadcast, [string]$NetworkName)

    if ($Sub -eq "-Help" -or -not $Sub) {
        Write-UpgradeHelp
        return
    }

    Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName

    switch ($Sub) {
        "implementation" {
            Write-Host "Upgrading Implementation..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/upgrade/UpgradeImplementation.s.sol:UpgradeImplementationScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        default {
            Write-Host "Unknown upgrade subcommand: $Sub" -ForegroundColor $Red
            Write-Host ""
            Write-Host "Available: implementation"
            Write-Host "Run '.\kondux-cli.ps1 upgrade -Help' for details"
            exit 1
        }
    }
}

function Invoke-Listing {
    param([string]$Sub, [hashtable]$Settings, [bool]$DoBroadcast, [string]$NetworkName)

    if ($Sub -eq "-Help" -or -not $Sub) {
        Write-ListingHelp
        return
    }

    switch ($Sub) {
        "create" {
            $tokenId = if ($Arguments[0]) { $Arguments[0] } else { "2" }
            $price = if ($Arguments[1]) { $Arguments[1] } else { "0.0001" }
            Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName
            if (-not $DoBroadcast) {
                Write-Host "[DRY-RUN] Would create listing for token $tokenId at $price ETH" -ForegroundColor $Yellow
                Write-Host "Command: node $ScriptDir\util\listOnOpenSea.js $tokenId $price"
            } else {
                Write-Host "Creating OpenSea listing for token $tokenId at $price ETH..." -ForegroundColor $Green
                node "$ScriptDir\util\listOnOpenSea.js" $tokenId $price
            }
        }
        "seaport" {
            Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName
            Write-Host "Creating Seaport listing..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/seaport/CreateSeaportListing.s.sol:CreateSeaportListingScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        default {
            Write-Host "Unknown listing subcommand: $Sub" -ForegroundColor $Red
            Write-Host ""
            Write-Host "Available: create, seaport"
            Write-Host "Run '.\kondux-cli.ps1 listing -Help' for details"
            exit 1
        }
    }
}

function Invoke-Utility {
    param([string]$Sub, [hashtable]$Settings, [bool]$DoBroadcast, [string]$NetworkName)

    if ($Sub -eq "-Help" -or -not $Sub) {
        Write-UtilityHelp
        return
    }

    switch ($Sub) {
        "fix-policy" {
            Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName
            Write-Host "Fixing Kondux Security Policy..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/utility/FixKonduxSecurityPolicy.s.sol:FixKonduxSecurityPolicyScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "sweep-eth" {
            Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName
            Write-Host "Sweeping Splitter ETH..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/utility/SweepSplitterETH.s.sol:SweepSplitterETHScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "copy-settings" {
            Write-ExecutionMode -DoBroadcast $DoBroadcast -NetworkName $NetworkName
            Write-Host "Copying NFT Settings..." -ForegroundColor $Green
            $cmd = Build-ForgeCmd "scripts/solidity/utility/CopyNFTSettings.s.sol:CopyNFTSettingsScript" $Settings $DoBroadcast
            Write-Host "Running: $cmd"
            Invoke-Expression $cmd
        }
        "extract-abis" {
            Write-Host "Extracting ABIs..." -ForegroundColor $Green
            node "$ScriptDir\util\extractAbis.js"
        }
        default {
            Write-Host "Unknown utility subcommand: $Sub" -ForegroundColor $Red
            Write-Host ""
            Write-Host "Available: fix-policy, sweep-eth, copy-settings, extract-abis"
            Write-Host "Run '.\kondux-cli.ps1 utility -Help' for details"
            exit 1
        }
    }
}

function Invoke-Build {
    param([string]$Sub)

    if ($Sub -eq "-Help" -or -not $Sub) {
        Write-BuildHelp
        return
    }

    switch ($Sub) {
        "compile" {
            Write-Host "Compiling contracts..." -ForegroundColor $Green
            & "$ScriptDir\forge.ps1" build
        }
        "test" {
            Write-Host "Running tests..." -ForegroundColor $Green
            & "$ScriptDir\forge.ps1" test -v @Arguments
        }
        "coverage" {
            Write-Host "Running coverage..." -ForegroundColor $Green
            & "$ScriptDir\forge.ps1" coverage @Arguments
        }
        default {
            Write-Host "Unknown build subcommand: $Sub" -ForegroundColor $Red
            Write-Host ""
            Write-Host "Available: compile, test, coverage"
            Write-Host "Run '.\kondux-cli.ps1 build -Help' for details"
            exit 1
        }
    }
}

function Invoke-Info {
    param([string]$Sub)

    if ($Sub -eq "-Help" -or -not $Sub) {
        Write-InfoHelp
        return
    }

    switch ($Sub) {
        "addresses" {
            Write-Host "Deployed Contract Addresses" -ForegroundColor $Green
            Write-Host ""
            Write-Host "Core Infrastructure:" -ForegroundColor $Yellow
            Write-Host "  KonduxBeaconFactory:    0xa265a01205f304F2652277AaC924AB56D2e0Cf77"
            Write-Host "  UpgradeableBeacon:      0x0aeD0fA92bCB03F7a37ad80D71AD181117B91F63"
            Write-Host "  KonduxImplementation:   0xeAfB6E3Ecc6676D3D7ac16F15F33E2B56C74af49"
            Write-Host ""
            Write-Host "Collections:" -ForegroundColor $Yellow
            Write-Host "  Kondux Test V2:         0x167a45aaC7a4512089eC6d401547351d7c73e66F"
            Write-Host "  Collection Splitter:    0x751435f5e2B2Db15EC72F0A9712bE7AF6a625De8"
            Write-Host ""
            Write-Host "Seaport Infrastructure:" -ForegroundColor $Yellow
            Write-Host "  Seaport 1.6:            0x0000000000000068F116a894984e2DB1123eB395"
            Write-Host "  OpenSea Conduit:        0x1E0049783F008A0085193E00003D00cd54003c71"
            Write-Host "  SeaportHelper:          0x92bC05d397Fc5d2E18d4d2DAf7EA8f60f7d67a1F"
            Write-Host ""
            Write-Host "Transfer Validator:" -ForegroundColor $Yellow
            Write-Host "  CreatorTokenTransferValidator: 0x721C00182a990771244d7A71B9FA2ea789A3b433"
        }
        "gas" {
            Write-Host "Running gas estimates..." -ForegroundColor $Green
            & "$ScriptDir\forge.ps1" test --gas-report
        }
        default {
            Write-Host "Unknown info subcommand: $Sub" -ForegroundColor $Red
            Write-Host ""
            Write-Host "Available: addresses, gas"
            Write-Host "Run '.\kondux-cli.ps1 info -Help' for details"
            exit 1
        }
    }
}

# =============================================================================
# Main Entry Point
# =============================================================================

# Handle version flag
if ($Version) {
    Write-Host "kondux-cli.ps1 v$CLI_VERSION"
    exit 0
}

# Handle help flag or no command
if ($Help -or -not $Command) {
    Write-Usage
    exit 0
}

# Handle 'help' command
if ($Command -eq "help") {
    if ($Subcommand) {
        switch ($Subcommand) {
            "deploy" { Write-DeployHelp }
            "upgrade" { Write-UpgradeHelp }
            "listing" { Write-ListingHelp }
            "utility" { Write-UtilityHelp }
            "build" { Write-BuildHelp }
            "info" { Write-InfoHelp }
            default { Write-Usage }
        }
    } else {
        Write-Usage
    }
    exit 0
}

# Determine network (default: sepolia for safety)
$script:NetworkName = "sepolia"
if ($Mainnet) { $script:NetworkName = "mainnet" }
elseif ($Local) { $script:NetworkName = "local" }
elseif ($Sepolia) { $script:NetworkName = "sepolia" }

# Determine broadcast mode (default: false/dry-run for safety)
$DoBroadcast = $Broadcast -and -not $DryRun

$NetworkSettings = Get-NetworkSettings $script:NetworkName

# Execute command
switch ($Command) {
    "deploy" { Invoke-Deploy $Subcommand $NetworkSettings $DoBroadcast $script:NetworkName }
    "upgrade" { Invoke-Upgrade $Subcommand $NetworkSettings $DoBroadcast $script:NetworkName }
    "listing" { Invoke-Listing $Subcommand $NetworkSettings $DoBroadcast $script:NetworkName }
    "utility" { Invoke-Utility $Subcommand $NetworkSettings $DoBroadcast $script:NetworkName }
    "build" { Invoke-Build $Subcommand }
    "info" { Invoke-Info $Subcommand }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor $Red
        Write-Host ""
        Write-Host "Available commands: deploy, upgrade, listing, utility, build, info"
        Write-Host "Run '.\kondux-cli.ps1 -Help' for usage information"
        exit 1
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor $Green
