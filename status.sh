#!/bin/bash
#
# status.sh - Read-only health check for autopilot loops
#
# Reports on any active or recent autopilot loop in the current repo:
# wrapper process liveness, loop-state iteration, task progress
# (passed/stuck/invalid), the current in-progress requirement, recent
# commits, notes-file staleness, and analytics.
#
# Makes NO changes - kills nothing, removes nothing. Safe to run anytime,
# including while a loop is actively running.
#
# Usage:
#   ./status.sh              # Auto-discover run.pid/command.pid in this repo
#   ./status.sh <taskfile>   # Check status for a specific task file
#   ./status.sh --help
#

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TASKFILE_ARG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "status.sh - Read-only health check for autopilot loops"
            echo ""
            echo "Usage:"
            echo "  ./status.sh              Auto-discover any run.pid/command.pid in this repo"
            echo "  ./status.sh <taskfile>   Check status for a specific task file"
            echo ""
            echo "Reports: wrapper process liveness, loop-state iteration, task progress"
            echo "(passed/stuck/invalid), the current in-progress requirement, recent"
            echo "commits, notes-file staleness, and analytics."
            echo ""
            echo "Read-only - kills nothing, removes nothing. Safe to run while a loop"
            echo "is active."
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            TASKFILE_ARG="$1"
            shift
            ;;
    esac
done

if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required${NC}"
    exit 1
fi

# --- Helpers (defined before use; called from the main loop below) ---

# Ask the wrapper process itself which task file it's running (authoritative -
# avoids guessing when a directory holds multiple *.json task files and
# loop-state.md happens to be briefly absent between iterations).
get_wrapper_taskfile() {
    local pid="$1"
    local cmdline=""
    if [[ -r "/proc/$pid/cmdline" ]]; then
        cmdline=$(tr '\0' '\n' < "/proc/$pid/cmdline")
    else
        cmdline=$(ps -o args= -p "$pid" 2>/dev/null | tr ' ' '\n')
    fi
    echo "$cmdline" | grep -E '\.json$' | head -1
}

report_analytics() {
    local analytics_file="$1"
    local actual_iter completed
    actual_iter=$(jq -r '.actualIterations // "?"' "$analytics_file" 2>/dev/null)
    completed=$(jq -r '.completedAt // "not yet"' "$analytics_file" 2>/dev/null)
    echo -e "  ${BLUE}Analytics:${NC} $analytics_file (actualIterations: $actual_iter, completedAt: $completed)"
}

report_task_file() {
    local task_file="$1"
    if [[ ! -f "$task_file" ]]; then
        echo -e "  ${YELLOW}Task file not found: $task_file${NC}"
        return
    fi

    local total passed stuck invalid
    total=$(jq '.requirements | length' "$task_file" 2>/dev/null)
    passed=$(jq '[.requirements[] | select(.passes == true)] | length' "$task_file" 2>/dev/null)
    stuck=$(jq '[.requirements[] | select(.stuck == true)] | length' "$task_file" 2>/dev/null)
    invalid=$(jq '[.requirements[] | select(.invalidTest == true)] | length' "$task_file" 2>/dev/null)

    echo ""
    echo -e "  ${BOLD}Task:${NC} $task_file"
    echo -e "  ${GREEN}Passed: ${passed:-0} / ${total:-0}${NC}   ${YELLOW}Stuck: ${stuck:-0}${NC}   Invalid: ${invalid:-0}"

    local current
    current=$(jq -r '
      [.requirements[] | select(.passes != true and .stuck != true and .invalidTest != true)] | .[0] |
      if . == null then "none - all complete, stuck, or invalid" else "[\(.id)] \(.description // "" | .[0:80])" end
    ' "$task_file" 2>/dev/null)
    echo -e "  Current: $current"

    if [[ "${stuck:-0}" -gt 0 ]]; then
        echo -e "  ${YELLOW}Stuck requirements:${NC}"
        jq -r '.requirements[] | select(.stuck == true) | "    [\(.id)] \(.description[0:60]) - \(.blockedReason // "no reason logged")"' "$task_file" 2>/dev/null
    fi

    # Notes-file staleness: flag (don't fix) a "Last completed: none/empty" note
    # once requirements have actually passed - git/task JSON remain ground truth.
    local notes_file=""
    for candidate in "${task_file}-notes.md" "${task_file%.json}-notes.md"; do
        [[ -f "$candidate" ]] && { notes_file="$candidate"; break; }
    done
    if [[ -n "$notes_file" ]]; then
        local notes_last
        notes_last=$(grep -m1 '^- Last completed:' "$notes_file" 2>/dev/null | sed 's/^- Last completed: *//')
        if [[ "${passed:-0}" -gt 0 && ( -z "$notes_last" || "$notes_last" == "none" ) ]]; then
            echo -e "  ${YELLOW}Notes file looks stale${NC} (\"$notes_file\" says \"Last completed: ${notes_last:-none}\" but $passed requirement(s) have passed) - harmless, git/task JSON are ground truth"
        fi
    fi

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo ""
        echo -e "  ${BLUE}Recent commits:${NC}"
        git log --oneline -6 2>/dev/null | sed 's/^/    /'
    fi
}

report_loop_state() {
    local state_file="$1"
    local iteration max_iterations task_file analytics_file command
    iteration=$(sed -n 's/^iteration: *//p' "$state_file" | head -1)
    max_iterations=$(sed -n 's/^max_iterations: *//p' "$state_file" | head -1)
    task_file=$(sed -n 's/^task_file: *//p' "$state_file" | head -1)
    analytics_file=$(sed -n 's/^analytics_file: *//p' "$state_file" | head -1)
    command=$(sed -n 's/^command: *//p' "$state_file" | head -1)

    local mtime_epoch now_epoch idle_secs
    mtime_epoch=$(stat -c %Y "$state_file" 2>/dev/null || stat -f %m "$state_file" 2>/dev/null)
    now_epoch=$(date +%s)
    idle_secs=$((now_epoch - mtime_epoch))

    echo -e "  Loop state:  iteration ${iteration:-?}/${max_iterations:-?}"
    if [[ $idle_secs -lt 120 ]]; then
        echo -e "  Last hook activity: ${GREEN}${idle_secs}s ago${NC}"
    elif [[ $idle_secs -lt 1800 ]]; then
        echo -e "  Last hook activity: ${YELLOW}$((idle_secs / 60))m ago${NC}"
    else
        echo -e "  Last hook activity: ${RED}$((idle_secs / 60))m ago${NC} (idle a while - not necessarily stuck, run.sh's own 30m timeout is the real backstop)"
    fi

    if [[ -n "$command" ]]; then
        echo -e "  Command mode: $command"
    elif [[ -n "$task_file" ]]; then
        report_task_file "$task_file"
    fi

    [[ -n "$analytics_file" && -f "$analytics_file" ]] && report_analytics "$analytics_file"
}

report_lock() {
    local lock_file="$1"
    local pid lock_dir is_alive=false
    pid=$(cat "$lock_file" 2>/dev/null)
    lock_dir=$(dirname "$lock_file")

    echo ""
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        is_alive=true
        local etimes elapsed
        etimes=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
        if [[ -n "$etimes" ]]; then
            elapsed="$((etimes / 60))m $((etimes % 60))s"
        else
            elapsed="unknown"
        fi
        echo -e "${GREEN}● Active wrapper${NC}  PID $pid  running $elapsed  ($lock_file)"
    else
        echo -e "${RED}○ Stale lock${NC}  PID ${pid:-?} is not running  ($lock_file)"
        echo -e "  ${YELLOW}Not removed (read-only) - '/autopilot stop' or 'rm $lock_file' to clean up${NC}"
    fi

    local state_file="$lock_dir/loop-state.md"
    if [[ -f "$state_file" ]]; then
        report_loop_state "$state_file"
        return
    fi

    echo -e "  ${YELLOW}No loop-state.md in $lock_dir${NC} (between iterations, in pre-flight, or just finished)"

    # loop-state.md is briefly absent between sessions - ask the live wrapper
    # process which task file it's actually running rather than guessing from
    # directory contents (a dir can hold several *.json task files).
    local task_file=""
    if [[ "$is_alive" == "true" ]]; then
        task_file=$(get_wrapper_taskfile "$pid")
    fi

    if [[ -n "$task_file" && -f "$task_file" ]]; then
        report_task_file "$task_file"
        return
    fi

    local candidates=()
    for candidate in "$lock_dir"/*.json; do
        [[ -f "$candidate" ]] && jq -e '.requirements' "$candidate" >/dev/null 2>&1 && candidates+=("$candidate")
    done
    if [[ ${#candidates[@]} -eq 1 ]]; then
        echo -e "  ${YELLOW}(only task JSON found in $lock_dir - not confirmed against the process)${NC}"
        report_task_file "${candidates[0]}"
    elif [[ ${#candidates[@]} -gt 1 ]]; then
        echo -e "  ${YELLOW}Cannot determine which task file is active${NC} (${#candidates[@]} candidates in $lock_dir: ${candidates[*]}). Try again shortly once loop-state.md reappears."
    fi
}

echo -e "${BOLD}Autopilot Status${NC}"
echo -e "${BLUE}────────────────────────────────────────${NC}"

LOCK_FILES=()
if [[ -n "$TASKFILE_ARG" ]]; then
    CANDIDATE="$(dirname "$TASKFILE_ARG")/run.pid"
    [[ -f "$CANDIDATE" ]] && LOCK_FILES+=("$CANDIDATE")
else
    while IFS= read -r f; do
        LOCK_FILES+=("$f")
    done < <(find . -maxdepth 5 \( -name run.pid -o -name command.pid \) -not -path "*/node_modules/*" 2>/dev/null)
fi

if [[ ${#LOCK_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No autopilot wrapper found (no run.pid/command.pid in this repo).${NC}"
    if [[ -f ".autopilot/loop-state.md" ]]; then
        echo ""
        echo -e "${BLUE}Found .autopilot/loop-state.md (in-session loop, no run.sh wrapper):${NC}"
        report_loop_state ".autopilot/loop-state.md"
    fi
    echo ""
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    exit 0
fi

for lock_file in "${LOCK_FILES[@]}"; do
    report_lock "$lock_file"
done

echo ""
echo -e "${BLUE}────────────────────────────────────────${NC}"
