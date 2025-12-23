#!/bin/bash
#
# Kondux CLI Test Suite (Bash)
# Validates basic CLI functionality
#
# Usage: ./scripts/tests/test-cli.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

test_header() {
    echo ""
    echo -e "${CYAN}Testing: $1${NC}"
    echo -e "${GRAY}$(printf '%0.s-' {1..50})${NC}"
}

test_pass() {
    ((PASSED++))
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

test_fail() {
    ((FAILED++))
    echo -e "  ${RED}[FAIL]${NC} $1"
    if [[ -n "$2" ]]; then
        echo -e "         ${GRAY}$2${NC}"
    fi
}

test_skip() {
    ((SKIPPED++))
    echo -e "  ${YELLOW}[SKIP]${NC} $1"
}

# =============================================================================
# Test: Script Files Exist
# =============================================================================
test_header "Script Files Exist"

scripts=(
    "kondux"
    "scripts/kondux-cli.sh"
    "scripts/shell/check-royalty.sh"
    "scripts/shell/check-splitter-state.sh"
    "scripts/shell/check-upgrade-state.sh"
    "scripts/shell/approve-conduit.sh"
    "scripts/shell/mint-one-nft.sh"
    "scripts/shell/list-on-opensea.sh"
    "scripts/shell/update-erc2981-royalty.sh"
    "scripts/shell/update-royalty-cuts.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "$ROOT_DIR/$script" ]]; then
        test_pass "$script exists"
    else
        test_fail "$script not found"
    fi
done

# =============================================================================
# Test: Scripts Are Executable
# =============================================================================
test_header "Scripts Are Executable"

for script in "${scripts[@]}"; do
    if [[ -x "$ROOT_DIR/$script" ]]; then
        test_pass "$script is executable"
    else
        test_fail "$script not executable"
    fi
done

# =============================================================================
# Test: Main Orchestrator Help
# =============================================================================
test_header "Main Orchestrator Help"

output=$("$ROOT_DIR/kondux" --help 2>&1) || true

if echo "$output" | grep -q "Kondux Smart Contracts CLI"; then
    test_pass "kondux --help shows banner"
else
    test_fail "kondux --help missing banner"
fi

if echo "$output" | grep -q "COMMANDS"; then
    test_pass "kondux --help shows commands section"
else
    test_fail "kondux --help missing commands section"
fi

if echo "$output" | grep -q "deploy" && echo "$output" | grep -q "upgrade"; then
    test_pass "kondux --help lists main commands"
else
    test_fail "kondux --help missing main commands"
fi

# =============================================================================
# Test: CLI Help Commands
# =============================================================================
test_header "CLI Help Commands"

help_commands=("deploy" "upgrade" "listing" "build" "info")

for cmd in "${help_commands[@]}"; do
    output=$("$ROOT_DIR/scripts/kondux-cli.sh" "$cmd" --help 2>&1) || true
    if echo "$output" | grep -qi "COMMAND: $cmd"; then
        test_pass "kondux-cli.sh $cmd --help works"
    else
        test_fail "kondux-cli.sh $cmd --help wrong output"
    fi
done

# =============================================================================
# Test: Shell Script Help
# =============================================================================
test_header "Shell Script Help"

shell_scripts=(
    "check-royalty.sh:check-royalty.sh"
    "check-splitter-state.sh:check-splitter-state.sh"
    "mint-one-nft.sh:mint-one-nft.sh"
    "approve-conduit.sh:approve-conduit.sh"
)

for entry in "${shell_scripts[@]}"; do
    script="${entry%%:*}"
    match="${entry##*:}"

    output=$("$ROOT_DIR/scripts/shell/$script" --help 2>&1) || true
    if echo "$output" | grep -q "$match"; then
        test_pass "$script --help works"
    else
        test_fail "$script --help wrong output"
    fi
done

# =============================================================================
# Test: Unknown Command Error
# =============================================================================
test_header "Error Handling"

output=$("$ROOT_DIR/kondux" "nonexistent-command" 2>&1) || true
if echo "$output" | grep -qi "unknown command\|error"; then
    test_pass "Unknown command shows error"
else
    test_fail "Unknown command should show error"
fi

# =============================================================================
# Test: Version Command
# =============================================================================
test_header "Version Command"

output=$("$ROOT_DIR/kondux" --version 2>&1) || true
if echo "$output" | grep -qE "kondux v[0-9]+\.[0-9]+\.[0-9]+"; then
    test_pass "Version command works"
else
    test_fail "Version command wrong format"
fi

# =============================================================================
# Test: Forge Available
# =============================================================================
test_header "Forge Available"

if command -v forge &> /dev/null; then
    test_pass "forge is installed"

    # Try a simple forge command
    if forge --version &> /dev/null; then
        test_pass "forge --version works"
    else
        test_fail "forge --version failed"
    fi
else
    test_skip "forge not installed"
fi

# =============================================================================
# Test: Cast Available
# =============================================================================
test_header "Cast Available"

if command -v cast &> /dev/null; then
    test_pass "cast is installed"

    if cast --version &> /dev/null; then
        test_pass "cast --version works"
    else
        test_fail "cast --version failed"
    fi
else
    test_skip "cast not installed"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=================================================="
echo -e "${NC}TEST SUMMARY${NC}"
echo "=================================================="
echo ""
echo -e "  Passed:  ${GREEN}$PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "  Failed:  ${RED}$FAILED${NC}"
else
    echo -e "  Failed:  ${GREEN}$FAILED${NC}"
fi
echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

TOTAL=$((PASSED + FAILED))
if [[ $TOTAL -gt 0 ]]; then
    PCT=$((PASSED * 100 / TOTAL))
else
    PCT=0
fi

if [[ $PCT -ge 80 ]]; then
    echo -e "  Pass Rate: ${GREEN}$PCT%${NC}"
elif [[ $PCT -ge 50 ]]; then
    echo -e "  Pass Rate: ${YELLOW}$PCT%${NC}"
else
    echo -e "  Pass Rate: ${RED}$PCT%${NC}"
fi
echo ""

if [[ $FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
