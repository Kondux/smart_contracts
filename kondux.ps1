#
# Kondux Smart Contracts - Main Orchestrator (PowerShell)
# Single entry point for all contract operations
#
# Usage: .\kondux.ps1 <command> [args...]
#

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Arguments,

    [Alias("h")]
    [switch]$Help,

    [Alias("v")]
    [switch]$Version
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLI_VERSION = "1.0.0"

# Colors
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"
$White = "White"
$Gray = "DarkGray"

function Write-Banner {
    Write-Host ""
    Write-Host "+==============================================+" -ForegroundColor $Cyan
    Write-Host "|       Kondux Smart Contracts CLI             |" -ForegroundColor $Cyan
    Write-Host "|              v$CLI_VERSION                         |" -ForegroundColor $Cyan
    Write-Host "+==============================================+" -ForegroundColor $Cyan
    Write-Host ""
}

function Show-Help {
    Write-Banner
    Write-Host "USAGE" -ForegroundColor $White
    Write-Host "    .\kondux.ps1 <command> [subcommand] [options]"
    Write-Host ""
    Write-Host "COMMANDS" -ForegroundColor $White
    Write-Host ""
    Write-Host "  Contract Operations" -ForegroundColor $Yellow -NoNewline; Write-Host " (via kondux-cli)"
    Write-Host "    deploy          Deploy smart contracts"
    Write-Host "    upgrade         Upgrade existing contracts"
    Write-Host "    listing         Create OpenSea/Seaport listings"
    Write-Host "    utility         Run utility operations"
    Write-Host "    info            Display contract information"
    Write-Host ""
    Write-Host "  Foundry Tools" -ForegroundColor $Yellow
    Write-Host "    build           Build contracts (forge build)"
    Write-Host "    test            Run tests (forge test)"
    Write-Host "    coverage        Generate coverage report"
    Write-Host "    forge           Run any forge command"
    Write-Host "    cast            Run any cast command"
    Write-Host ""
    Write-Host "  Shell Utilities" -ForegroundColor $Yellow -NoNewline; Write-Host " (scripts/shell/)"
    Write-Host "    check-royalty       Check ERC2981 royalty info"
    Write-Host "    check-splitter      Check splitter state"
    Write-Host "    check-upgrade       Check proxy upgrade state"
    Write-Host "    approve-conduit     Approve OpenSea conduit"
    Write-Host "    mint                Mint an NFT"
    Write-Host "    update-royalty      Update ERC2981 royalty"
    Write-Host "    update-cuts         Update splitter cuts"
    Write-Host "    list-opensea        List NFT on OpenSea"
    Write-Host ""
    Write-Host "  Help" -ForegroundColor $Yellow
    Write-Host "    help, -Help, -h     Show this help message"
    Write-Host "    version, -Version   Show version"
    Write-Host "    <command> -Help     Show help for a specific command"
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor $White
    Write-Host "    .\kondux.ps1 build                         # Build contracts"
    Write-Host "    .\kondux.ps1 test -vvv                     # Run tests verbosely"
    Write-Host "    .\kondux.ps1 deploy collection -Sepolia    # Deploy to Sepolia"
    Write-Host "    .\kondux.ps1 check-royalty                 # Check royalty config"
    Write-Host "    .\kondux.ps1 cast call 0x... `"totalSupply()`" --rpc-url mainnet"
    Write-Host ""
    Write-Host "NETWORKS" -ForegroundColor $White
    Write-Host "    -Sepolia      Use Sepolia testnet (default)"
    Write-Host "    -Mainnet      Use Ethereum mainnet"
    Write-Host "    -Local        Use local Anvil node"
    Write-Host ""
    Write-Host "SAFETY" -ForegroundColor $White
    Write-Host "    Default: Sepolia network + dry-run mode"
    Write-Host "    Use -Mainnet -Broadcast for production transactions"
    Write-Host ""
    exit 0
}

function Invoke-ShellScript {
    param([string]$ScriptPath, [string[]]$Args)

    if (-not (Test-Path $ScriptPath)) {
        Write-Host "Error: Script not found: $ScriptPath" -ForegroundColor $Red
        exit 1
    }

    # Convert to WSL path and execute
    $driveLetter = $ScriptPath.Substring(0, 1).ToLower()
    $wslPath = $ScriptPath.Substring(2) -replace '\\', '/'
    $wslPath = "/mnt/$driveLetter$wslPath"

    # Quote arguments with spaces
    $argsString = ""
    if ($Args -and $Args.Count -gt 0) {
        $argsString = ($Args | ForEach-Object {
            if ($_ -match '\s') { "'$_'" } else { $_ }
        }) -join ' '
    }

    # Shell scripts handle their own cd to project root
    wsl bash -c "'$wslPath' $argsString"
}

# Handle version flag FIRST (before help, since empty command triggers help)
if ($Version -or $Command -eq "version" -or $Command -eq "--version") {
    Write-Host "kondux v$CLI_VERSION"
    exit 0
}

# Handle help flag
if ($Help -or $Command -eq "help" -or $Command -eq "--help" -or $Command -eq "-h" -or [string]::IsNullOrEmpty($Command)) {
    Show-Help
}

# Route commands
switch ($Command) {
    # Foundry shortcuts
    "build" {
        & "$ScriptDir\scripts\kondux-cli.ps1" build compile @Arguments
    }
    "test" {
        & "$ScriptDir\scripts\kondux-cli.ps1" build test @Arguments
    }
    "coverage" {
        & "$ScriptDir\scripts\kondux-cli.ps1" build coverage @Arguments
    }
    "forge" {
        & "$ScriptDir\scripts\forge.ps1" @Arguments
    }
    "cast" {
        & "$ScriptDir\scripts\cast.ps1" @Arguments
    }

    # Contract operations (forward to kondux-cli)
    { $_ -in @("deploy", "upgrade", "listing", "utility", "info") } {
        & "$ScriptDir\scripts\kondux-cli.ps1" $Command @Arguments
    }

    # Shell utility shortcuts (via WSL)
    "check-royalty" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\check-royalty.sh" $Arguments
    }
    "check-splitter" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\check-splitter-state.sh" $Arguments
    }
    "check-upgrade" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\check-upgrade-state.sh" $Arguments
    }
    "approve-conduit" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\approve-conduit.sh" $Arguments
    }
    "mint" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\mint-one-nft.sh" $Arguments
    }
    "update-royalty" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\update-erc2981-royalty.sh" $Arguments
    }
    "update-cuts" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\update-royalty-cuts.sh" $Arguments
    }
    "list-opensea" {
        Invoke-ShellScript "$ScriptDir\scripts\shell\list-on-opensea.sh" $Arguments
    }

    # Unknown command
    default {
        Write-Host "Error: Unknown command '$Command'" -ForegroundColor $Red
        Write-Host ""
        Write-Host "Run '.\kondux.ps1 -Help' for usage information."
        exit 1
    }
}
