#!/bin/bash
#
# run.sh - Token-frugal wrapper for Claude Code autopilot
#
# Runs autopilot with fresh context for each requirement by invoking
# Claude in a loop, completing one requirement per session.
#
# Usage:
#   ./run.sh <taskfile.json> [options]    # Task file mode
#   ./run.sh /<command> [options]          # Command loop mode
#
# Options:
#   --batch N       Complete N requirements per session (default: 1, task mode only)
#   --max N         Maximum iterations/command runs (default: 10, command mode only)
#   --delay N       Seconds to wait between sessions (default: 2)
#   --model MODEL   Claude model to use (opus, sonnet, haiku, or full name)
#   --cleanup       Kill stale Claude processes before starting
#   --dry-run       Show what would be done without executing
#   --help          Show this help message
#
# Examples:
#   ./run.sh docs/tasks/prds/feature.json
#   ./run.sh docs/tasks/prds/feature.json --batch 3
#   ./run.sh docs/tasks/prds/feature.json --model sonnet
#   ./run.sh docs/tasks/prds/feature.json --delay 5
#   ./run.sh /my-command --max 5
#   ./run.sh /review-pr 123 --max 3

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Process cleanup helpers ---

# Get all descendant PIDs of a process (recursive)
get_descendants() {
    local pid=$1
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        echo "$child"
        get_descendants "$child"
    done
}

# Kill a Claude session and all its child processes
# Collects descendant PIDs before killing the parent (they reparent to init after)
kill_session() {
    local pid=$1

    if ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    # Collect all descendant PIDs BEFORE killing parent
    # (once parent dies, children reparent to init and we lose the tree)
    local descendants
    descendants=$(get_descendants "$pid")

    # Send SIGTERM to main process and all descendants
    kill -TERM "$pid" 2>/dev/null || true
    for desc in $descendants; do
        kill -TERM "$desc" 2>/dev/null || true
    done

    # Wait for graceful shutdown (up to 5 seconds)
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 5 ]]; do
        sleep 1
        waited=$((waited + 1))
    done

    # Force kill any survivors
    kill -KILL "$pid" 2>/dev/null || true
    for desc in $descendants; do
        kill -KILL "$desc" 2>/dev/null || true
    done
}

# Kill stale Claude/MCP processes from previous sessions
# Only targets background processes (no controlling terminal)
cleanup_stale_processes() {
    local patterns="(/home/joe/.local/bin/claude|claude-mem.*mcp-server|chroma-mcp|worker-service)"
    local count=0
    local pids=""

    while IFS= read -r line; do
        local pid tty
        pid=$(echo "$line" | awk '{print $2}')
        tty=$(echo "$line" | awk '{print $7}')

        # Skip processes with a controlling terminal (active sessions)
        [[ "$tty" != "?" ]] && continue
        # Skip our own process
        [[ "$pid" == "$$" ]] && continue

        pids="$pids $pid"
        count=$((count + 1))
        local cmd
        cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}' | head -c 80)
        echo -e "  ${YELLOW}Killing${NC} PID $pid: $cmd"
    done < <(ps aux 2>/dev/null | grep -E "$patterns" | grep -v -E "grep|run\.sh|cleanup\.sh" || true)

    if [[ $count -eq 0 ]]; then
        echo -e "${GREEN}No stale processes found${NC}"
        return 0
    fi

    # Wait briefly, then force kill survivors
    sleep 2
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
    echo -e "${GREEN}Cleaned up $count stale process(es)${NC}"
}

# --- End process cleanup helpers ---

# Default values
BATCH_SIZE="1"  # Default: 1 requirement per session (fresh context)
MAX_ITERATIONS=10  # Default: 10 iterations for command mode
DELAY=2
DRY_RUN=false
CLEANUP=false
MODEL=""  # Empty means use Claude's default (opus)
TASKFILE=""
COMMAND=""  # Slash command for command loop mode
COMMAND_ARGS=""  # Arguments for the slash command
MODE="task"  # "task" or "command"

# PID file for signal-based shutdown
PID_FILE=".autopilot.pid"
STOP_REQUESTED=false
CURRENT_CLAUDE_PID=""

# Signal handler for graceful shutdown
handle_stop() {
    STOP_REQUESTED=true
}

trap handle_stop SIGUSR1 SIGINT SIGTERM

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --batch)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --max)
            MAX_ITERATIONS="$2"
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
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "run.sh - Token-frugal wrapper for Claude Code autopilot"
            echo ""
            echo "Usage:"
            echo "  ./run.sh <taskfile.json> [options]    # Task file mode"
            echo "  ./run.sh /<command> [args] [options]  # Command loop mode"
            echo ""
            echo "Options:"
            echo "  --batch N       Complete N requirements per session (default: 1, task mode)"
            echo "  --max N         Maximum command runs (default: 10, command mode)"
            echo "  --delay N       Seconds to wait between sessions (default: 2)"
            echo "  --model MODEL   Claude model: opus, sonnet, haiku, or full name"
            echo "  --cleanup       Kill stale Claude processes before starting"
            echo "  --dry-run       Show what would be done without executing"
            echo "  --help          Show this help message"
            echo ""
            echo "Task mode runs Claude Code autopilot in a loop, starting a fresh"
            echo "session for each batch of requirements."
            echo ""
            echo "Command mode runs a slash command repeatedly with fresh sessions."
            echo "Example: ./run.sh /my-command --max 5"
            echo ""
            echo "Requirements:"
            echo "  - Claude Code CLI installed"
            echo "  - Task file must be valid JSON with 'requirements' array (task mode)"
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        /*)
            # Slash command - switch to command mode
            if [[ -z "$COMMAND" ]]; then
                COMMAND="$1"
                MODE="command"
            else
                # Additional argument for the command
                COMMAND_ARGS="$COMMAND_ARGS $1"
            fi
            shift
            ;;
        *)
            if [[ "$MODE" == "command" ]]; then
                # Argument for the slash command
                COMMAND_ARGS="$COMMAND_ARGS $1"
            elif [[ -z "$TASKFILE" ]]; then
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
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: Claude Code CLI is required but not installed${NC}"
    echo ""
    echo "Install Claude Code CLI:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Or visit: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

# Mode-specific validation
if [[ "$MODE" == "command" ]]; then
    # Command mode validation
    if [[ -z "$COMMAND" ]]; then
        echo -e "${RED}Error: No command specified${NC}"
        echo "Usage: ./run.sh /<command> [args] [options]"
        exit 1
    fi
else
    # Task mode validation - requires jq and valid task file
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

    if [[ -z "$TASKFILE" ]]; then
        echo -e "${RED}Error: No task file or command specified${NC}"
        echo "Usage:"
        echo "  ./run.sh <taskfile.json> [options]    # Task file mode"
        echo "  ./run.sh /<command> [args] [options]  # Command loop mode"
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

cleanup_on_exit() {
    # Kill any running Claude session and its children
    if [[ -n "$CURRENT_CLAUDE_PID" ]] && kill -0 "$CURRENT_CLAUDE_PID" 2>/dev/null; then
        echo -e "\n${YELLOW}Cleaning up Claude session (PID $CURRENT_CLAUDE_PID)...${NC}" >&2
        kill_session "$CURRENT_CLAUDE_PID"
        wait "$CURRENT_CLAUDE_PID" 2>/dev/null || true
    fi
    # Sweep for any daemonized children that escaped the process tree
    # (MCP servers started with --daemon double-fork and reparent to init)
    cleanup_stale_processes
    rm -f "$PID_FILE"
}
trap cleanup_on_exit EXIT

# Sentinel file for stop signal from autopilot command
STOP_SIGNAL_FILE=".autopilot/stop-signal"

# Clean up any stale stop signal file from previous runs
rm -f "$STOP_SIGNAL_FILE"

# Run stale process cleanup if requested
if [[ "$CLEANUP" == "true" ]]; then
    echo -e "${BLUE}Cleaning up stale processes...${NC}"
    cleanup_stale_processes
    echo ""
fi

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

# Build Claude CLI options (shared between modes)
CLAUDE_OPTS="--dangerously-skip-permissions"
if [[ -n "$MODEL" ]]; then
    CLAUDE_OPTS="$CLAUDE_OPTS --model $MODEL"
fi

# ============================================================================
# COMMAND MODE LOOP
# ============================================================================
if [[ "$MODE" == "command" ]]; then
    FULL_COMMAND="$COMMAND$COMMAND_ARGS"

    echo -e "${GREEN}Starting run.sh (command mode)${NC}"
    echo -e "Command: ${FULL_COMMAND}"
    echo -e "Max iterations: ${MAX_ITERATIONS}"
    echo -e "Delay between sessions: ${DELAY}s"
    if [[ -n "$MODEL" ]]; then
        echo -e "Model: ${MODEL}"
    fi
    echo ""

    ITERATION=0

    while [[ "$ITERATION" -lt "$MAX_ITERATIONS" ]]; do
        # Check for stop signal
        if check_stop; then
            echo -e "${BLUE}----------------------------------------${NC}"
            echo -e "${BLUE}Command:${NC} $FULL_COMMAND"
            echo -e "${GREEN}Completed:${NC} $ITERATION / $MAX_ITERATIONS iterations"
            echo -e "${BLUE}----------------------------------------${NC}"
            break
        fi

        ITERATION=$((ITERATION + 1))
        echo ""
        echo -e "${BLUE}=== Iteration $ITERATION of $MAX_ITERATIONS ===${NC}"
        echo -e "${BLUE}Running:${NC} $FULL_COMMAND"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${YELLOW}[DRY RUN] Would execute:${NC}"
            echo "  claude $CLAUDE_OPTS \"$FULL_COMMAND\""
            echo ""
            echo -e "${YELLOW}Simulating command execution...${NC}"
            if [[ $ITERATION -ge 3 ]]; then
                echo -e "${YELLOW}[DRY RUN] Stopping after 3 simulated iterations${NC}"
                break
            fi
        else
            echo -e "${BLUE}Starting Claude Code session...${NC}"
            echo ""

            # Create loop state file to instruct Claude to run command and exit
            mkdir -p .autopilot
            cat > .autopilot/loop-state.md << LOOPSTATE
---
iteration: 1
max_iterations: 1
completion_promise: COMPLETE
command: $FULL_COMMAND
---

Run the slash command $FULL_COMMAND.

After the command completes, immediately output COMPLETE and exit. Do not wait for user input.
LOOPSTATE

            # Run Claude with the command wrapped in autonomous instructions
            claude $CLAUDE_OPTS "Run $FULL_COMMAND autonomously. Do not ask for user input - make reasonable choices yourself. When the command completes, output COMPLETE and stop." &
            CLAUDE_PID=$!
            CURRENT_CLAUDE_PID=$CLAUDE_PID

            # Wait for Claude to finish (stop-hook will handle exit on COMPLETE)
            IDLE_SECONDS=0
            while kill -0 "$CLAUDE_PID" 2>/dev/null; do
                if [[ "$STOP_REQUESTED" == "true" ]]; then
                    kill_session "$CLAUDE_PID"
                    wait "$CLAUDE_PID" 2>/dev/null || true
                    CURRENT_CLAUDE_PID=""
                    rm -f ".autopilot/loop-state.md"
                    echo -e "${YELLOW}Stopped${NC}"
                    exit 0
                fi

                # Check for sentinel stop file
                if [[ -f "$STOP_SIGNAL_FILE" ]]; then
                    kill_session "$CLAUDE_PID"
                    wait "$CLAUDE_PID" 2>/dev/null || true
                    CURRENT_CLAUDE_PID=""
                    rm -f "$STOP_SIGNAL_FILE" ".autopilot/loop-state.md"
                    echo -e "${GREEN}Command signaled completion${NC}"
                    break
                fi

                # Timeout after 10 minutes of no activity
                IDLE_SECONDS=$((IDLE_SECONDS + 2))
                if [[ "$IDLE_SECONDS" -ge 600 ]]; then
                    echo -e "${YELLOW}Timeout - terminating session${NC}"
                    kill_session "$CLAUDE_PID"
                    break
                fi

                sleep 2
            done

            wait "$CLAUDE_PID" 2>/dev/null || true
            CLAUDE_EXIT=$?
            CURRENT_CLAUDE_PID=""
            rm -f ".autopilot/loop-state.md"

            # Sweep for daemonized children that escaped kill_session
            cleanup_stale_processes

            echo ""
            if [[ "$CLAUDE_EXIT" -eq 0 ]]; then
                echo -e "${GREEN}Iteration $ITERATION complete${NC}"
            else
                echo -e "${YELLOW}Iteration $ITERATION exited with code $CLAUDE_EXIT${NC}"
            fi

            # Check for stop signal after session completes
            if check_stop; then
                echo -e "${BLUE}----------------------------------------${NC}"
                echo -e "${BLUE}Command:${NC} $FULL_COMMAND"
                echo -e "${GREEN}Completed:${NC} $ITERATION / $MAX_ITERATIONS iterations"
                echo -e "${BLUE}----------------------------------------${NC}"
                break
            fi
        fi

        # Brief pause between sessions if more iterations remain
        if [[ "$ITERATION" -lt "$MAX_ITERATIONS" ]]; then
            echo -e "${BLUE}Waiting ${DELAY}s before next iteration...${NC}"
            sleep "$DELAY"
        fi
    done

    echo ""
    echo -e "${GREEN}run.sh finished (command mode)${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Command:${NC} $FULL_COMMAND"
    echo -e "${GREEN}Completed:${NC} $ITERATION / $MAX_ITERATIONS iterations"
    echo -e "${BLUE}----------------------------------------${NC}"
    exit 0
fi

# ============================================================================
# TASK MODE LOOP
# ============================================================================
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

        # Run Claude in background so we can monitor for batch completion
        claude $CLAUDE_OPTS "$AUTOPILOT_CMD" &
        CLAUDE_PID=$!
        CURRENT_CLAUDE_PID=$CLAUDE_PID

        # Monitor for batch completion by checking task JSON
        IDLE_TIMEOUT=600  # 10 minutes with no progress = assume stuck
        LAST_PROGRESS=0
        IDLE_SECONDS=0

        while kill -0 "$CLAUDE_PID" 2>/dev/null; do
            # Check for manual stop request
            if [[ "$STOP_REQUESTED" == "true" ]]; then
                echo ""
                echo -e "${YELLOW}Stop signal received - terminating session...${NC}"
                kill_session "$CLAUDE_PID"
                wait "$CLAUDE_PID" 2>/dev/null || true
                CURRENT_CLAUDE_PID=""
                print_status
                echo -e "${GREEN}run.sh stopped${NC}"
                exit 0
            fi

            # Check for sentinel stop file
            if [[ -f "$STOP_SIGNAL_FILE" ]]; then
                echo ""
                echo -e "${GREEN}All requirements complete - stopping...${NC}"
                kill_session "$CLAUDE_PID"
                wait "$CLAUDE_PID" 2>/dev/null || true
                CURRENT_CLAUDE_PID=""
                rm -f "$STOP_SIGNAL_FILE"
                print_status
                echo -e "${GREEN}run.sh finished${NC}"
                exit 0
            fi

            # Check task JSON for batch completion
            CURRENT_COMPLETED=$(count_completed)
            CURRENT_STUCK=$(count_stuck)
            PROGRESS=$((CURRENT_COMPLETED + CURRENT_STUCK - COMPLETED_BEFORE - STUCK_BEFORE))

            if [[ "$PROGRESS" -ge "$BATCH_SIZE" ]]; then
                sleep 2  # Give Claude a moment to finish output
                echo ""
                echo -e "${GREEN}Batch complete ($PROGRESS requirement(s)) - terminating for fresh context...${NC}"
                kill_session "$CLAUDE_PID"
                rm -f ".autopilot/loop-state.md"
                break
            fi

            # Track idle time - restart if progress made but now idle
            if [[ "$PROGRESS" -gt "$LAST_PROGRESS" ]]; then
                LAST_PROGRESS=$PROGRESS
                IDLE_SECONDS=0
            else
                IDLE_SECONDS=$((IDLE_SECONDS + 2))
                # If we made progress and now idle for 30s, restart for fresh context
                if [[ "$PROGRESS" -gt 0 && "$IDLE_SECONDS" -ge 30 ]]; then
                    echo ""
                    echo -e "${GREEN}Progress made ($PROGRESS requirement(s)) - restarting for fresh context...${NC}"
                    kill_session "$CLAUDE_PID"
                    rm -f ".autopilot/loop-state.md"
                    break
                fi
                # No progress at all and idle too long = stuck
                if [[ "$PROGRESS" -eq 0 && "$IDLE_SECONDS" -ge "$IDLE_TIMEOUT" ]]; then
                    echo ""
                    echo -e "${YELLOW}No progress for ${IDLE_TIMEOUT}s - terminating idle session...${NC}"
                    kill_session "$CLAUDE_PID"
                    rm -f ".autopilot/loop-state.md"
                    break
                fi
            fi

            sleep 2
        done

        # Wait for Claude to finish
        wait "$CLAUDE_PID" 2>/dev/null || true
        CLAUDE_EXIT=$?
        CURRENT_CLAUDE_PID=""

        # Sweep for daemonized children that escaped kill_session
        cleanup_stale_processes

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
