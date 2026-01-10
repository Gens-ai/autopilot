#!/bin/bash
#
# run.sh - Token-frugal wrapper for Claude Code autopilot
#
# Runs autopilot with fresh context for each requirement by invoking
# Claude in a loop, completing one requirement per session.
#
# Usage:
#   ./run.sh <taskfile.json> [options]
#
# Options:
#   --batch N       Complete N requirements per session (default: all)
#   --delay N       Seconds to wait between sessions (default: 2)
#   --dry-run       Show what would be done without executing
#   --help          Show this help message
#
# Examples:
#   ./run.sh docs/tasks/prds/feature.json
#   ./run.sh docs/tasks/prds/feature.json --batch 3
#   ./run.sh docs/tasks/prds/feature.json --delay 5

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BATCH_SIZE=""
DELAY=2
DRY_RUN=false
TASKFILE=""

# Stop file - checked each iteration to allow graceful shutdown
STOP_FILE=".autopilot-stop"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --batch)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --delay)
            DELAY="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "run.sh - Token-frugal wrapper for Claude Code autopilot"
            echo ""
            echo "Usage: ./run.sh <taskfile.json> [options]"
            echo ""
            echo "Options:"
            echo "  --batch N       Complete N requirements per session (default: all)"
            echo "  --delay N       Seconds to wait between sessions (default: 2)"
            echo "  --dry-run       Show what would be done without executing"
            echo "  --help          Show this help message"
            echo ""
            echo "This script runs Claude Code autopilot in a loop, starting a fresh"
            echo "session for each batch of requirements. This keeps context small"
            echo "and token usage efficient."
            echo ""
            echo "Requirements:"
            echo "  - Claude Code CLI installed"
            echo "  - Task file must be valid JSON with 'requirements' array"
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            if [[ -z "$TASKFILE" ]]; then
                TASKFILE="$1"
            else
                echo -e "${RED}Unexpected argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate taskfile
if [[ -z "$TASKFILE" ]]; then
    echo -e "${RED}Error: No task file specified${NC}"
    echo "Usage: ./run.sh <taskfile.json> [options]"
    exit 1
fi

if [[ ! -f "$TASKFILE" ]]; then
    echo -e "${RED}Error: Task file not found: $TASKFILE${NC}"
    exit 1
fi

# Clean up any existing stop file from previous runs
if [[ -f "$STOP_FILE" ]]; then
    rm "$STOP_FILE"
    echo -e "${YELLOW}Removed stale stop file${NC}"
fi

# Function to check for stop signal
check_stop() {
    if [[ -f "$STOP_FILE" ]]; then
        echo ""
        echo -e "${YELLOW}Stop signal received (found $STOP_FILE)${NC}"
        echo -e "${YELLOW}Stopping autopilot loop...${NC}"
        rm "$STOP_FILE"
        return 0
    fi
    return 1
}

# Function to count incomplete requirements
count_incomplete() {
    # Count requirements where passes is false/missing AND not stuck AND not invalidTest
    local count
    count=$(jq '[.requirements[] | select(.passes != true and .stuck != true and .invalidTest != true)] | length' "$TASKFILE" 2>/dev/null || echo "0")
    echo "$count"
}

# Function to count completed requirements
count_completed() {
    local count
    count=$(jq '[.requirements[] | select(.passes == true)] | length' "$TASKFILE" 2>/dev/null || echo "0")
    echo "$count"
}

# Function to count stuck requirements
count_stuck() {
    local count
    count=$(jq '[.requirements[] | select(.stuck == true)] | length' "$TASKFILE" 2>/dev/null || echo "0")
    echo "$count"
}

# Function to count total requirements
count_total() {
    local count
    count=$(jq '.requirements | length' "$TASKFILE" 2>/dev/null || echo "0")
    echo "$count"
}

# Print status
print_status() {
    local total completed stuck incomplete
    total=$(count_total)
    completed=$(count_completed)
    stuck=$(count_stuck)
    incomplete=$(count_incomplete)

    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Task File:${NC} $TASKFILE"
    echo -e "${GREEN}Completed:${NC} $completed / $total"
    echo -e "${YELLOW}Stuck:${NC} $stuck"
    echo -e "${BLUE}Remaining:${NC} $incomplete"
    echo -e "${BLUE}----------------------------------------${NC}"
}

# Main loop
echo -e "${GREEN}Starting run.sh${NC}"
echo -e "Batch size: $BATCH_SIZE requirement(s) per session"
echo -e "Delay between sessions: ${DELAY}s"
echo ""

SESSION=0

while true; do
    # Check for stop signal
    if check_stop; then
        print_status
        break
    fi

    # Check how many requirements remain
    INCOMPLETE=$(count_incomplete)

    if [[ "$INCOMPLETE" -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}All requirements complete!${NC}"
        print_status
        break
    fi

    SESSION=$((SESSION + 1))
    echo ""
    echo -e "${BLUE}=== Session $SESSION ===${NC}"
    print_status

    # Build the autopilot command
    AUTOPILOT_CMD="/autopilot $TASKFILE"
    if [[ -n "$BATCH_SIZE" ]]; then
        AUTOPILOT_CMD="$AUTOPILOT_CMD --batch $BATCH_SIZE"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN] Would execute:${NC}"
        echo "  claude --dangerously-skip-permissions \"$AUTOPILOT_CMD\""
        echo ""
        echo -e "${YELLOW}Simulating completion of ${BATCH_SIZE:-all} requirement(s)...${NC}"
        # In dry run, we'd need to manually exit
        if [[ $SESSION -ge 3 ]]; then
            echo -e "${YELLOW}[DRY RUN] Stopping after 3 simulated sessions${NC}"
            break
        fi
    else
        echo -e "${BLUE}Starting Claude Code session...${NC}"
        echo ""

        # Run Claude with autopilot command
        # Using --dangerously-skip-permissions for autonomous operation
        if ! claude --dangerously-skip-permissions "$AUTOPILOT_CMD"; then
            echo -e "${YELLOW}Session ended with non-zero exit code${NC}"
            # Continue anyway - might just be normal completion
        fi

        echo ""
        echo -e "${GREEN}Session $SESSION complete${NC}"

        # Check for stop signal after session
        if check_stop; then
            print_status
            break
        fi
    fi

    # Brief pause between sessions (only if batching)
    if [[ -n "$BATCH_SIZE" && "$INCOMPLETE" -gt "$BATCH_SIZE" ]]; then
        echo -e "${BLUE}Waiting ${DELAY}s before next session...${NC}"
        sleep "$DELAY"
    elif [[ -z "$BATCH_SIZE" ]]; then
        # No batching - single session completes all, so exit loop
        break
    fi
done

echo ""
echo -e "${GREEN}run.sh finished${NC}"
print_status
