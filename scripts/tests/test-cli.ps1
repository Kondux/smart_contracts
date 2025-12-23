#
# Kondux CLI Test Suite (PowerShell)
# Validates basic CLI functionality
#
# Usage: .\scripts\tests\test-cli.ps1
#

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$Passed = 0
$Failed = 0
$Skipped = 0

function Write-TestHeader {
    param([string]$Name)
    Write-Host ""
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    Write-Host ("-" * 50) -ForegroundColor DarkGray
}

function Test-Pass {
    param([string]$Message)
    $script:Passed++
    Write-Host "  [PASS] $Message" -ForegroundColor Green
}

function Test-Fail {
    param([string]$Message, [string]$Details = "")
    $script:Failed++
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
    if ($Details) {
        Write-Host "         $Details" -ForegroundColor DarkGray
    }
}

function Test-Skip {
    param([string]$Message)
    $script:Skipped++
    Write-Host "  [SKIP] $Message" -ForegroundColor Yellow
}

# =============================================================================
# Test: Script Files Exist
# =============================================================================
Write-TestHeader "Script Files Exist"

$scripts = @(
    "kondux.ps1",
    "scripts\kondux-cli.ps1",
    "scripts\forge.ps1",
    "scripts\cast.ps1",
    "scripts\shell\check-royalty.sh",
    "scripts\shell\check-splitter-state.sh",
    "scripts\shell\check-upgrade-state.sh",
    "scripts\shell\approve-conduit.sh",
    "scripts\shell\mint-one-nft.sh",
    "scripts\shell\list-on-opensea.sh",
    "scripts\shell\update-erc2981-royalty.sh",
    "scripts\shell\update-royalty-cuts.sh"
)

foreach ($script in $scripts) {
    $path = Join-Path $RootDir $script
    if (Test-Path $path) {
        Test-Pass "$script exists"
    } else {
        Test-Fail "$script not found"
    }
}

# =============================================================================
# Test: Main Orchestrator Help
# =============================================================================
Write-TestHeader "Main Orchestrator Help"

$output = & "$RootDir\kondux.ps1" -Help *>&1 | Out-String
if ($output -like "*Kondux*CLI*") {
    Test-Pass "kondux.ps1 -Help shows banner"
} else {
    Test-Fail "kondux.ps1 -Help missing banner"
}

if ($output -like "*COMMANDS*") {
    Test-Pass "kondux.ps1 -Help shows commands section"
} else {
    Test-Fail "kondux.ps1 -Help missing commands section"
}

if ($output -like "*deploy*" -and $output -like "*upgrade*") {
    Test-Pass "kondux.ps1 -Help lists main commands"
} else {
    Test-Fail "kondux.ps1 -Help missing main commands"
}

# =============================================================================
# Test: CLI Help Commands
# =============================================================================
Write-TestHeader "CLI Help Commands"

$helpCommands = @("deploy", "upgrade", "listing", "build", "info")

foreach ($cmd in $helpCommands) {
    $output = & "$RootDir\scripts\kondux-cli.ps1" $cmd -Help *>&1 | Out-String
    # Each command help should mention the command name and have DESCRIPTION or USAGE
    if ($output -like "*$cmd*" -and ($output -like "*DESCRIPTION*" -or $output -like "*USAGE*" -or $output -like "*SUBCOMMANDS*")) {
        Test-Pass "kondux-cli.ps1 $cmd -Help works"
    } else {
        Test-Fail "kondux-cli.ps1 $cmd -Help wrong output"
    }
}

# =============================================================================
# Test: Shell Script Help
# =============================================================================
Write-TestHeader "Shell Script Help (via WSL)"

# Check if WSL is available
$wslAvailable = $false
try {
    $null = wsl --version 2>&1
    $wslAvailable = $true
} catch {
    $wslAvailable = $false
}

if ($wslAvailable) {
    $shellScripts = @(
        @{ Script = "check-royalty.sh"; Match = "check-royalty.sh" },
        @{ Script = "check-splitter-state.sh"; Match = "check-splitter-state.sh" },
        @{ Script = "mint-one-nft.sh"; Match = "mint-one-nft.sh" }
    )

    foreach ($test in $shellScripts) {
        try {
            $scriptPath = "$RootDir\scripts\shell\$($test.Script)"
            $driveLetter = $scriptPath.Substring(0, 1).ToLower()
            $wslPath = $scriptPath.Substring(2) -replace '\\', '/'
            $wslPath = "/mnt/$driveLetter$wslPath"

            $output = wsl bash -c "'$wslPath' --help" 2>&1 | Out-String
            if ($output -match $test.Match) {
                Test-Pass "$($test.Script) --help works"
            } else {
                Test-Fail "$($test.Script) --help wrong output"
            }
        } catch {
            Test-Fail "$($test.Script) --help failed" $_.Exception.Message
        }
    }
} else {
    Test-Skip "WSL not available - skipping shell script tests"
}

# =============================================================================
# Test: Unknown Command Error
# =============================================================================
Write-TestHeader "Error Handling"

# Write-Host output goes to Information stream (6), need to capture all
$output = & "$RootDir\kondux.ps1" "nonexistent-command" *>&1 | Out-String
if ($output -like "*Unknown command*" -or $output -like "*Error*") {
    Test-Pass "Unknown command shows error"
} else {
    Test-Fail "Unknown command should show error"
}

# =============================================================================
# Test: Version Command
# =============================================================================
Write-TestHeader "Version Command"

$output = & "$RootDir\kondux.ps1" -Version *>&1 | Out-String
if ($output -like "*kondux v*") {
    Test-Pass "Version command works"
} else {
    Test-Fail "Version command wrong format" "Got: $output"
}

# =============================================================================
# Test: Info Addresses (no network required)
# =============================================================================
Write-TestHeader "Info Addresses"

$output = & "$RootDir\scripts\kondux-cli.ps1" info addresses *>&1 | Out-String
if ($output -like "*0x*" -and ($output -like "*Factory*" -or $output -like "*Collection*" -or $output -like "*Splitter*")) {
    Test-Pass "Info addresses shows contract info"
} else {
    Test-Fail "Info addresses missing contract info"
}

# =============================================================================
# Summary
# =============================================================================
Write-Host ""
Write-Host ("=" * 50) -ForegroundColor White
Write-Host "TEST SUMMARY" -ForegroundColor White
Write-Host ("=" * 50) -ForegroundColor White
Write-Host ""
Write-Host "  Passed:  $Passed" -ForegroundColor Green
Write-Host "  Failed:  $Failed" -ForegroundColor $(if ($Failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped: $Skipped" -ForegroundColor Yellow
Write-Host ""

$Total = $Passed + $Failed
$Pct = if ($Total -gt 0) { [math]::Round(($Passed / $Total) * 100) } else { 0 }
Write-Host "  Pass Rate: $Pct%" -ForegroundColor $(if ($Pct -ge 80) { "Green" } elseif ($Pct -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

if ($Failed -gt 0) {
    exit 1
} else {
    exit 0
}
