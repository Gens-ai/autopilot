#!/bin/bash
#
# stop-hook.sh - Autopilot loop mechanism
#
# This hook intercepts Claude's exit attempts and re-feeds the prompt
# to create an iterative TDD loop with context accumulation.
#
# Based on the Ralph Loop technique but bundled with autopilot.
#

set -e

# State file location (in project directory)
STATE_FILE=".autopilot/loop-state.md"

# Check if state file exists - if not, allow exit (not in a loop)
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Read state from YAML frontmatter
iteration=$(sed -n 's/^iteration: *//p' "$STATE_FILE" | head -1)
max_iterations=$(sed -n 's/^max_iterations: *//p' "$STATE_FILE" | head -1)
completion_promise=$(sed -n 's/^completion_promise: *//p' "$STATE_FILE" | head -1)

# Validate iteration is numeric
if ! [[ "$iteration" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid iteration value: $iteration" >&2
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# Check if we've hit max iterations
if [[ "$iteration" -ge "$max_iterations" ]]; then
    echo "Max iterations ($max_iterations) reached" >&2
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# Check for completion promise in the transcript
# The transcript is passed via CLAUDE_TRANSCRIPT environment variable or we read it
TRANSCRIPT_FILE="${CLAUDE_TRANSCRIPT:-}"

if [[ -n "$TRANSCRIPT_FILE" && -f "$TRANSCRIPT_FILE" ]]; then
    # Read the last assistant message from JSONL transcript
    last_message=$(tail -20 "$TRANSCRIPT_FILE" 2>/dev/null | grep '"role":"assistant"' | tail -1 || true)

    if [[ -n "$last_message" && -n "$completion_promise" ]]; then
        # Check if completion promise appears in the message
        # Look for <promise>COMPLETE</promise> pattern or just the promise text
        if echo "$last_message" | grep -q "<promise>$completion_promise</promise>"; then
            echo "Completion promise detected: $completion_promise" >&2
            rm -f "$STATE_FILE"
            echo '{"decision": "allow"}'
            exit 0
        fi

        # Also check for just outputting the promise (simpler detection)
        if echo "$last_message" | grep -q "\"$completion_promise\""; then
            echo "Completion detected: $completion_promise" >&2
            rm -f "$STATE_FILE"
            echo '{"decision": "allow"}'
            exit 0
        fi
    fi
fi

# Extract the prompt (everything after the YAML frontmatter)
prompt=$(sed '1,/^---$/d' "$STATE_FILE" | sed '1,/^---$/d')

# If no prompt found (malformed state file), allow exit
if [[ -z "$prompt" ]]; then
    echo "Error: No prompt found in state file" >&2
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# Increment iteration counter
new_iteration=$((iteration + 1))
sed -i "s/^iteration: *[0-9]*/iteration: $new_iteration/" "$STATE_FILE"

# Build system message with iteration info
system_message="Iteration $new_iteration of $max_iterations. Continue working on the task. Output $completion_promise when complete."

# Block exit and re-feed the prompt
# The reason field contains the prompt to re-execute
cat << EOF
{
  "decision": "block",
  "reason": $(echo "$prompt" | jq -Rs .),
  "systemMessage": "$system_message"
}
EOF
