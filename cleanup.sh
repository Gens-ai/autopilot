#!/bin/bash
#
# cleanup.sh - Kill orphaned Claude Code processes
#
# Claude Code can leave behind orphaned MCP servers, subagent processes,
# and worker threads that consume memory indefinitely. This script finds
# and kills them.
#
# Usage:
#   ./cleanup.sh           # Kill background orphans only (safe)
#   ./cleanup.sh --all     # Kill ALL Claude-related processes
#   ./cleanup.sh --dry-run # Show what would be killed without killing
#   ./cleanup.sh --help    # Show help
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODE="background"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            MODE="all"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "cleanup.sh - Kill orphaned Claude Code processes"
            echo ""
            echo "Usage:"
            echo "  ./cleanup.sh           Kill background/orphaned processes only (safe)"
            echo "  ./cleanup.sh --all     Kill ALL Claude-related processes"
            echo "  ./cleanup.sh --dry-run Show what would be killed"
            echo ""
            echo "By default, only kills processes with no controlling terminal (orphans)."
            echo "Use --all to also kill processes attached to terminals."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Run with --help for usage"
            exit 1
            ;;
    esac
done

# Patterns matching Claude Code and its typical child processes
PATTERNS="(/home/joe/.local/bin/claude|claude-mem.*mcp-server|chroma-mcp|worker-service\.cjs)"

FOUND=0
PIDS=""

echo -e "${BLUE}Scanning for Claude-related processes...${NC}"
if [[ "$MODE" == "background" ]]; then
    echo -e "${BLUE}Mode: background only (orphans without controlling terminal)${NC}"
else
    echo -e "${YELLOW}Mode: ALL Claude-related processes${NC}"
fi
echo ""

while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $2}')
    tty=$(echo "$line" | awk '{print $7}')
    start=$(echo "$line" | awk '{print $9}')
    mem=$(echo "$line" | awk '{print $6}')
    cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}' | head -c 100)

    # Skip our own script
    [[ "$pid" == "$$" ]] && continue

    # In background mode, skip processes with a controlling terminal
    if [[ "$MODE" == "background" && "$tty" != "?" ]]; then
        continue
    fi

    # Convert RSS (KB) to MB for display
    mem_mb=$((mem / 1024))

    FOUND=$((FOUND + 1))
    PIDS="$PIDS $pid"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}Would kill${NC} PID $pid (${mem_mb}MB, tty=$tty, started=$start)"
        echo -e "    $cmd"
    else
        echo -e "  ${RED}Killing${NC} PID $pid (${mem_mb}MB, tty=$tty, started=$start)"
        echo -e "    $cmd"
        kill -TERM "$pid" 2>/dev/null || true
    fi
done < <(ps aux 2>/dev/null | grep -E "$PATTERNS" | grep -v -E "grep|cleanup\.sh" || true)

echo ""

if [[ $FOUND -eq 0 ]]; then
    echo -e "${GREEN}No Claude-related processes found${NC}"
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}$FOUND process(es) would be killed${NC}"
    echo "Run without --dry-run to kill them."
    exit 0
fi

# Wait for graceful shutdown, then force kill survivors
echo -e "${BLUE}Waiting for graceful shutdown...${NC}"
sleep 3

SURVIVORS=0
for pid in $PIDS; do
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "  ${RED}Force killing${NC} PID $pid (did not respond to SIGTERM)"
        kill -KILL "$pid" 2>/dev/null || true
        SURVIVORS=$((SURVIVORS + 1))
    fi
done

echo ""
echo -e "${GREEN}Cleaned up $FOUND process(es)${NC}"
if [[ $SURVIVORS -gt 0 ]]; then
    echo -e "${YELLOW}$SURVIVORS required SIGKILL (force kill)${NC}"
fi
