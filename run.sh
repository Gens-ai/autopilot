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
#   --batch N       Complete N requirements per session (default: 1)
#   --delay N       Seconds to wait between sessions (default: 2)
#   --model MODEL   Claude model to use (opus, sonnet, haiku, or full name)
#   --dry-run       Show what would be done without executing
#   --help          Show this help message
#
# Examples:
#   ./run.sh docs/tasks/prds/feature.json
#   ./run.sh docs/tasks/prds/feature.json --batch 3
#   ./run.sh docs/tasks/prds/feature.json --model sonnet
#   ./run.sh docs/tasks/prds/feature.json --delay 5

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BATCH_SIZE="1"  # Default: 1 requirement per session (fresh context)
DELAY=2
DRY_RUN=false
MODEL=""  # Empty means use Claude's default (opus)
TASKFILE=""

# PID file for signal-based shutdown
PID_FILE=".autopilot.pid"
STOP_REQUESTED=false

# Signal handler for graceful shutdown
handle_stop() {
    STOP_REQUESTED=true
}

trap handle_stop SIGUSR1

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
        --model)
            MODEL="$2"
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
            echo "  --batch N       Complete N requirements per session (default: 1)"
            echo "  --delay N       Seconds to wait between sessions (default: 2)"
            echo "  --model MODEL   Claude model: opus, sonnet, haiku, or full name"
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

# Check for required dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    echo ""
    echo "Install jq using your package manager:"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt-get install jq"
    echo "  Fedora:  sudo dnf install jq"
    echo "  Arch:    sudo pacman -S jq"
    echo ""
    echo "Or visit: https://jqlang.github.io/jq/download/"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: Claude Code CLI is required but not installed${NC}"
    echo ""
    echo "Install Claude Code CLI:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Or visit: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

# Validate taskfile
if [[ -z "$TASKFILE" ]]; then
    echo -e "${RED}Error: No task file specified${NC}"
    echo "Usage: ./run.sh <taskfile.json> [options]"
    exit 1
fi

if [[ ! -f "$TASKFILE" ]]; then
    echo -e "${RED}Error: Task file not found: $TASKFILE${NC}"
    echo ""
    echo "Common task file locations:"
    echo "  docs/tasks/prds/<feature>.json"
    echo "  tasks/<feature>.json"
    echo ""
    echo "Run '/tasks <prd-file.md>' to generate a task file from a PRD."
    exit 1
fi

# Validate task file is valid JSON with requirements array
if ! jq empty "$TASKFILE" 2>/dev/null; then
    echo -e "${RED}Error: Task file is not valid JSON: $TASKFILE${NC}"
    echo ""
    echo "Check for syntax errors like:"
    echo "  - Missing commas between items"
    echo "  - Unclosed brackets or braces"
    echo "  - Trailing commas before closing brackets"
    echo ""
    echo "Validate with: jq . $TASKFILE"
    exit 1
fi

if ! jq -e '.requirements' "$TASKFILE" >/dev/null 2>&1; then
    echo -e "${RED}Error: Task file missing 'requirements' array: $TASKFILE${NC}"
    echo ""
    echo "Task files must have a 'requirements' array. Example:"
    echo '  { "requirements": [{ "id": "1", "description": "..." }] }'
    echo ""
    echo "Run '/tasks <prd-file.md>' to generate a valid task file."
    exit 1
fi

# Check if another instance is running
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${RED}Error: Another autopilot instance is running (PID $OLD_PID)${NC}"
        echo -e "${YELLOW}Use '/autopilot stop' to stop it, or 'kill -USR1 $OLD_PID'${NC}"
        exit 1
    else
        echo -e "${YELLOW}Removed stale PID file${NC}"
    fi
fi

# Write our PID and ensure cleanup on exit
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

# Sentinel file for stop signal from autopilot command
STOP_SIGNAL_FILE=".autopilot/stop-signal"

# Clean up any stale stop signal file from previous runs
rm -f "$STOP_SIGNAL_FILE"

# Function to check for stop signal (either SIGUSR1 or sentinel file)
check_stop() {
    if [[ "$STOP_REQUESTED" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}Stop signal received (SIGUSR1)${NC}"
        echo -e "${YELLOW}Stopping autopilot loop...${NC}"
        return 0
    fi
    if [[ -f "$STOP_SIGNAL_FILE" ]]; then
        echo ""
        echo -e "${GREEN}Stop signal received (sentinel file)${NC}"
        echo -e "${GREEN}Autopilot requested exit.${NC}"
        rm -f "$STOP_SIGNAL_FILE"
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
echo -e "Batch size: ${BATCH_SIZE} requirement(s) per session"
echo -e "Delay between sessions: ${DELAY}s"
if [[ -n "$MODEL" ]]; then
    echo -e "Model: ${MODEL}"
fi
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

    # Build Claude CLI options
    CLAUDE_OPTS="--dangerously-skip-permissions"
    if [[ -n "$MODEL" ]]; then
        CLAUDE_OPTS="$CLAUDE_OPTS --model $MODEL"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN] Would execute:${NC}"
        echo "  claude $CLAUDE_OPTS \"$AUTOPILOT_CMD\""
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

        # Track progress before session
        COMPLETED_BEFORE=$(count_completed)
        STUCK_BEFORE=$(count_stuck)

        # Run Claude in foreground - user watches the full TUI
        claude $CLAUDE_OPTS "$AUTOPILOT_CMD"
        CLAUDE_EXIT=$?

        echo ""

        # Track progress after session
        COMPLETED_AFTER=$(count_completed)
        STUCK_AFTER=$(count_stuck)
        COMPLETED_THIS_SESSION=$((COMPLETED_AFTER - COMPLETED_BEFORE))
        STUCK_THIS_SESSION=$((STUCK_AFTER - STUCK_BEFORE))

        # Show session result
        if [[ "$CLAUDE_EXIT" -eq 0 ]]; then
            echo -e "${GREEN}Session $SESSION complete${NC}"
        else
            echo -e "${YELLOW}Session $SESSION exited with code $CLAUDE_EXIT${NC}"
        fi

        # Show progress made this session
        if [[ "$COMPLETED_THIS_SESSION" -gt 0 ]]; then
            echo -e "${GREEN}  + $COMPLETED_THIS_SESSION requirement(s) completed${NC}"
        fi
        if [[ "$STUCK_THIS_SESSION" -gt 0 ]]; then
            echo -e "${YELLOW}  + $STUCK_THIS_SESSION requirement(s) stuck${NC}"
        fi
        if [[ "$COMPLETED_THIS_SESSION" -eq 0 && "$STUCK_THIS_SESSION" -eq 0 ]]; then
            echo -e "${YELLOW}  No progress this session (may need manual intervention)${NC}"
        fi

        # Check for stop signal after session completes
        if check_stop; then
            print_status
            break
        fi
    fi

    # Brief pause between sessions if more requirements remain than batch size
    if [[ "$INCOMPLETE" -gt "$BATCH_SIZE" ]]; then
        echo -e "${BLUE}Waiting ${DELAY}s before next session...${NC}"
        sleep "$DELAY"
    fi
done

echo ""
echo -e "${GREEN}run.sh finished${NC}"
print_status
