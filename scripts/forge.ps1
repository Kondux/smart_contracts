#
# Forge PowerShell Wrapper
# Executes Foundry's forge command via WSL with environment variable support
#

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForgeArgs,

    [Alias("h")]
    [switch]$Help
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

function Show-Help {
    Write-Host ""
    Write-Host "NAME" -ForegroundColor White
    Write-Host "    forge.ps1 - PowerShell wrapper for Foundry's forge command"
    Write-Host ""
    Write-Host "SYNOPSIS" -ForegroundColor White
    Write-Host "    .\scripts\forge.ps1 [-Help] <forge-arguments>"
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor White
    Write-Host "    Executes Foundry's forge command via WSL (Windows Subsystem for Linux)."
    Write-Host "    Automatically loads environment variables from .env, exports required"
    Write-Host "    keys, and provides convenient RPC URL aliases (mainnet, sepolia)."
    Write-Host ""
    Write-Host "OPTIONS" -ForegroundColor White
    Write-Host "    -Help, -h       Show this help message and exit"
    Write-Host ""
    Write-Host "RPC URL ALIASES" -ForegroundColor White
    Write-Host "    mainnet         Substituted with `$MAINNET_RPC_URL from .env"
    Write-Host "    sepolia         Substituted with `$SEPOLIA_RPC_URL from .env"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES (auto-exported to WSL)" -ForegroundColor White
    Write-Host "    PROD_DEPLOYER_PK    Production deployer private key"
    Write-Host "    DEPLOYER_PK         Development deployer private key"
    Write-Host "    ETHERSCAN_API_KEY   For contract verification"
    Write-Host "    ALCHEMY_API_KEY     For RPC access"
    Write-Host "    MAINNET_RPC_URL     Ethereum mainnet RPC endpoint"
    Write-Host "    SEPOLIA_RPC_URL     Sepolia testnet RPC endpoint"
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor White
    Write-Host "    # Build contracts"
    Write-Host "    .\scripts\forge.ps1 build"
    Write-Host ""
    Write-Host "    # Run tests"
    Write-Host "    .\scripts\forge.ps1 test -vvv"
    Write-Host ""
    Write-Host "    # Run a script (dry-run)"
    Write-Host "    .\scripts\forge.ps1 script script/Deploy.s.sol --rpc-url sepolia -vvv"
    Write-Host ""
    Write-Host "    # Run a script with broadcast"
    Write-Host "    .\scripts\forge.ps1 script script/Deploy.s.sol --rpc-url mainnet --broadcast --verify -vvv"
    Write-Host ""
    Write-Host "    # Generate coverage report"
    Write-Host "    .\scripts\forge.ps1 coverage --report lcov"
    Write-Host ""
    Write-Host "NOTE" -ForegroundColor White
    Write-Host "    Requires WSL with Foundry installed at ~/.foundry/bin/forge"
    Write-Host ""
    Write-Host "SEE ALSO" -ForegroundColor White
    Write-Host "    .\scripts\kondux-cli.ps1 - Unified CLI for common operations"
    Write-Host ""
    exit 0
}

if ($Help -or $ForgeArgs.Count -eq 0) {
    Show-Help
}

# Load .env file if it exists
$envFile = Join-Path $RootDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove surrounding quotes if present
            $value = $value -replace '^["'']|["'']$', ''
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Convert Windows path to WSL path (e.g., D:\git\smart_contracts -> /mnt/d/git/smart_contracts)
$driveLetter = $RootDir.Substring(0, 1).ToLower()
$pathWithoutDrive = $RootDir.Substring(2) -replace '\\', '/'
$wslPath = "/mnt/$driveLetter$pathWithoutDrive"

# Common environment setup
$envSetup = @(
    "export FOUNDRY_DISABLE_NIGHTLY_WARNING=1"
    "export PROD_DEPLOYER_PK='$env:PROD_DEPLOYER_PK'"
    "export DEPLOYER_PK='$env:DEPLOYER_PK'"
    "export ETHERSCAN_API_KEY='$env:ETHERSCAN_API_KEY'"
    "export ALCHEMY_API_KEY='$env:ALCHEMY_API_KEY'"
) -join "; "

# RPC URL substitution map
$rpcUrls = @{
    "mainnet" = $env:MAINNET_RPC_URL
    "sepolia" = $env:SEPOLIA_RPC_URL
}

# Process arguments: quote those with special chars and substitute RPC URLs
$processedArgs = @()
$skipNext = $false
for ($i = 0; $i -lt $ForgeArgs.Count; $i++) {
    if ($skipNext) {
        $skipNext = $false
        continue
    }

    $arg = $ForgeArgs[$i]

    # Handle --rpc-url substitution
    if ($arg -eq "--rpc-url" -and ($i + 1) -lt $ForgeArgs.Count) {
        $rpcValue = $ForgeArgs[$i + 1]
        if ($rpcUrls.ContainsKey($rpcValue) -and $rpcUrls[$rpcValue]) {
            $processedArgs += $arg
            $processedArgs += $rpcUrls[$rpcValue]
            $skipNext = $true
            continue
        }
    }

    # Quote arguments containing special shell characters
    if ($arg -match '[(){};\s]') {
        $processedArgs += "'$arg'"
    } else {
        $processedArgs += $arg
    }
}

$argsString = $processedArgs -join ' '

# Execute via WSL
$cmd = "cd '$wslPath' && $envSetup && ~/.foundry/bin/forge $argsString"
wsl bash -c $cmd
