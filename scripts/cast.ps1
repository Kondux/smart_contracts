#
# Cast PowerShell Wrapper
# Executes Foundry's cast command via WSL with environment variable support
#

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CastArgs,

    [Alias("h")]
    [switch]$Help
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

function Show-Help {
    Write-Host ""
    Write-Host "NAME" -ForegroundColor White
    Write-Host "    cast.ps1 - PowerShell wrapper for Foundry's cast command"
    Write-Host ""
    Write-Host "SYNOPSIS" -ForegroundColor White
    Write-Host "    .\scripts\cast.ps1 [-Help] <cast-arguments>"
    Write-Host ""
    Write-Host "DESCRIPTION" -ForegroundColor White
    Write-Host "    Executes Foundry's cast command via WSL (Windows Subsystem for Linux)."
    Write-Host "    Automatically loads environment variables from .env and provides"
    Write-Host "    convenient RPC URL aliases (mainnet, sepolia)."
    Write-Host ""
    Write-Host "OPTIONS" -ForegroundColor White
    Write-Host "    -Help, -h       Show this help message and exit"
    Write-Host ""
    Write-Host "RPC URL ALIASES" -ForegroundColor White
    Write-Host "    mainnet         Substituted with `$MAINNET_RPC_URL from .env"
    Write-Host "    sepolia         Substituted with `$SEPOLIA_RPC_URL from .env"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES" -ForegroundColor White
    Write-Host "    MAINNET_RPC_URL     Ethereum mainnet RPC endpoint"
    Write-Host "    SEPOLIA_RPC_URL     Sepolia testnet RPC endpoint"
    Write-Host ""
    Write-Host "EXAMPLES" -ForegroundColor White
    Write-Host "    # Query total supply of a contract"
    Write-Host "    .\scripts\cast.ps1 call 0x167a45aa... `"totalSupply()(uint256)`" --rpc-url mainnet"
    Write-Host ""
    Write-Host "    # Get ETH balance of an address"
    Write-Host "    .\scripts\cast.ps1 balance 0x41BC231d... --rpc-url mainnet"
    Write-Host ""
    Write-Host "    # Read storage slot"
    Write-Host "    .\scripts\cast.ps1 storage 0x167a45aa... 0 --rpc-url mainnet"
    Write-Host ""
    Write-Host "    # Encode function call"
    Write-Host "    .\scripts\cast.ps1 calldata `"transfer(address,uint256)`" 0xRecipient 1000"
    Write-Host ""
    Write-Host "NOTE" -ForegroundColor White
    Write-Host "    Requires WSL with Foundry installed at ~/.foundry/bin/cast"
    Write-Host ""
    exit 0
}

if ($Help -or $CastArgs.Count -eq 0) {
    Show-Help
}

# Load .env file if it exists
$envFile = Join-Path $RootDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            $value = $value -replace '^["'']|["'']$', ''
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# RPC URL substitution map
$rpcUrls = @{
    "mainnet" = $env:MAINNET_RPC_URL
    "sepolia" = $env:SEPOLIA_RPC_URL
}

# Process arguments: quote those with special chars and substitute RPC URLs
$processedArgs = @()
$skipNext = $false
for ($i = 0; $i -lt $CastArgs.Count; $i++) {
    if ($skipNext) {
        $skipNext = $false
        continue
    }

    $arg = $CastArgs[$i]

    # Handle --rpc-url substitution
    if ($arg -eq "--rpc-url" -and ($i + 1) -lt $CastArgs.Count) {
        $rpcValue = $CastArgs[$i + 1]
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
$cmd = "export FOUNDRY_DISABLE_NIGHTLY_WARNING=1 && ~/.foundry/bin/cast $argsString"
wsl bash -c $cmd
