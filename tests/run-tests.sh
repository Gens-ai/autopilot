#!/bin/bash
#
# run-tests.sh - Test suite for run.sh
#
# Usage: ./tests/run-tests.sh
#
# Zero dependencies - just bash.

# Don't use set -e, we need to capture exit codes from failing commands

# Change to repo root
cd "$(dirname "$0")/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Test helper
test_it() {
    local name="$1"
    local condition="$2"
    ((TOTAL++))

    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} $name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $name"
        ((FAILED++))
    fi
}

# Strip ANSI color codes from output
strip_colors() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Test helper for checking output contains string
output_contains() {
    local clean_output
    clean_output=$(strip_colors "$OUTPUT")
    [[ "$clean_output" == *"$1"* ]]
}

# Test helper for checking exit code
exited_with() {
    [[ "$EXIT_CODE" == "$1" ]]
}

echo "Running run.sh tests..."
echo ""

# ============================================
# Basic argument handling
# ============================================
echo "## Argument handling"

# Test: --help shows usage
OUTPUT=$(./run.sh --help 2>&1) ; EXIT_CODE=$?
test_it "--help shows usage info" 'output_contains "Usage:" && exited_with 0'

# Test: -h also works
OUTPUT=$(./run.sh -h 2>&1) ; EXIT_CODE=$?
test_it "-h also shows help" 'output_contains "Usage:" && exited_with 0'

# Test: No arguments shows error
OUTPUT=$(./run.sh 2>&1) ; EXIT_CODE=$?
test_it "no arguments shows error" 'output_contains "No task file specified"'

# Test: Non-existent file shows error
OUTPUT=$(./run.sh nonexistent.json 2>&1) ; EXIT_CODE=$?
test_it "non-existent file shows error" 'output_contains "not found"'

# Test: Unknown option shows error
OUTPUT=$(./run.sh --unknown 2>&1) ; EXIT_CODE=$?
test_it "unknown option shows error" 'output_contains "Unknown option"'

echo ""

# ============================================
# Requirement counting
# ============================================
echo "## Requirement counting"

# Test: All complete exits immediately
OUTPUT=$(./run.sh tests/fixtures/all-complete.json --dry-run 2>&1)
EXIT_CODE=$?
test_it "all complete: exits immediately" 'output_contains "All requirements complete" && exited_with 0'
test_it "all complete: shows 3/3 completed" 'output_contains "Completed: 3 / 3"'
test_it "all complete: shows 0 remaining" 'output_contains "Remaining: 0"'

# Test: Empty requirements exits immediately
OUTPUT=$(./run.sh tests/fixtures/empty.json --dry-run 2>&1)
EXIT_CODE=$?
test_it "empty: exits immediately" 'output_contains "All requirements complete" && exited_with 0'
test_it "empty: shows 0/0 completed" 'output_contains "Completed: 0 / 0"'

# Test: Incomplete shows correct counts
OUTPUT=$(./run.sh tests/fixtures/incomplete.json --dry-run 2>&1)
EXIT_CODE=$?
test_it "incomplete: shows 1/3 completed" 'output_contains "Completed: 1 / 3"'
test_it "incomplete: shows 2 remaining" 'output_contains "Remaining: 2"'

# Test: Mixed stuck/invalid counts correctly
OUTPUT=$(./run.sh tests/fixtures/mixed-stuck.json --dry-run 2>&1)
EXIT_CODE=$?
test_it "mixed: shows 1/4 completed" 'output_contains "Completed: 1 / 4"'
test_it "mixed: shows 1 stuck" 'output_contains "Stuck: 1"'
test_it "mixed: shows 1 remaining (not 3)" 'output_contains "Remaining: 1"'

echo ""

# ============================================
# Dry run behavior
# ============================================
echo "## Dry run behavior"

# Test: Dry run shows what would be executed
OUTPUT=$(./run.sh tests/fixtures/incomplete.json --dry-run 2>&1)
EXIT_CODE=$?
test_it "dry-run: shows command that would run" 'output_contains "[DRY RUN] Would execute"'
test_it "dry-run: mentions claude command" 'output_contains "claude"'
test_it "dry-run: stops after simulated sessions" 'output_contains "Stopping after"'

echo ""

# ============================================
# Option parsing
# ============================================
echo "## Option parsing"

# Test: --batch is recognized
OUTPUT=$(./run.sh tests/fixtures/incomplete.json --batch 3 --dry-run 2>&1)
EXIT_CODE=$?
test_it "--batch: sets batch size" 'output_contains "Batch size: 3"'

# Test: --delay is recognized
OUTPUT=$(./run.sh tests/fixtures/incomplete.json --delay 5 --dry-run 2>&1)
EXIT_CODE=$?
test_it "--delay: sets delay" 'output_contains "Delay between sessions: 5s"'

# Test: Multiple options work together
OUTPUT=$(./run.sh tests/fixtures/incomplete.json --batch 2 --delay 10 --dry-run 2>&1)
EXIT_CODE=$?
test_it "multiple options: all parsed" 'output_contains "Batch size: 2" && output_contains "Delay between sessions: 10s"'

echo ""

# ============================================
# Summary
# ============================================
echo "========================================"
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All $TOTAL tests passed${NC}"
    exit 0
else
    echo -e "${RED}$FAILED of $TOTAL tests failed${NC}"
    exit 1
fi
