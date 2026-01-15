#!/bin/bash
#
# stop-hook.sh - Autopilot loop mechanism
#
# This hook intercepts Claude's stop events and either:
# 1. Blocks exit and re-feeds the prompt (continues TDD loop)
# 2. Forces exit when COMPLETE is detected or max iterations reached
#
# Based on the Ralph Loop technique but bundled with autopilot.
#
# Hook Input (JSON via stdin):
#   { "transcript_path": "/path/to/transcript.jsonl", ... }
#
# Hook Output (JSON):
#   { "decision": "block", "reason": "prompt", "systemMessage": "info" } - continue loop
#   { "decision": "allow" } + SIGTERM to parent - force exit when complete
#

# Don't exit on error - we need to handle errors gracefully
set +e

# State file location (in project directory)
STATE_FILE=".autopilot/loop-state.md"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if state file exists - if not, allow exit (not in a loop)
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Read state from YAML frontmatter
iteration=$(sed -n 's/^iteration: *//p' "$STATE_FILE" | head -1)
max_iterations=$(sed -n 's/^max_iterations: *//p' "$STATE_FILE" | head -1)
completion_promise=$(sed -n 's/^completion_promise: *//p' "$STATE_FILE" | head -1)
started_at=$(sed -n 's/^started_at: *//p' "$STATE_FILE" | head -1)

# Validate iteration is numeric
if ! [[ "$iteration" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid iteration value: $iteration" >&2
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# Validate max_iterations is numeric
if ! [[ "$max_iterations" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid max_iterations value: $max_iterations" >&2
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# Check if we've hit max iterations (0 means unlimited)
if [[ "$max_iterations" -gt 0 && "$iteration" -ge "$max_iterations" ]]; then
    echo "Max iterations ($max_iterations) reached" >&2
    rm -f "$STATE_FILE"

    # Force exit by sending SIGTERM to the Claude process
    (sleep 0.5 && kill -TERM $PPID 2>/dev/null) &

    echo '{"decision": "allow"}'
    exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_FILE=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# Check for completion promise in the transcript
echo "DEBUG: Checking for completion promise. TRANSCRIPT_FILE=$TRANSCRIPT_FILE, completion_promise=$completion_promise" >&2
if [[ -n "$TRANSCRIPT_FILE" && -f "$TRANSCRIPT_FILE" && -n "$completion_promise" ]]; then
    # Read the last assistant message from JSONL transcript
    # Search last 50 lines for assistant messages
    last_message=$(tail -50 "$TRANSCRIPT_FILE" 2>/dev/null | grep '"role"[[:space:]]*:[[:space:]]*"assistant"' | tail -1 || true)
    echo "DEBUG: last_message found: $(echo "$last_message" | head -c 200)..." >&2

    if [[ -n "$last_message" ]]; then
        # Extract text content from the message
        message_text=$(echo "$last_message" | jq -r '.content // .text // empty' 2>/dev/null || true)
        echo "DEBUG: message_text length: ${#message_text}" >&2

        if [[ -n "$message_text" ]]; then
            # Use Perl to extract text between <promise> tags (more robust than grep)
            # This handles multiline and special characters properly
            promise_content=$(echo "$message_text" | perl -ne 'print $1 if /<promise>\s*(.*?)\s*<\/promise>/s' 2>/dev/null || true)
            echo "DEBUG: promise_content='$promise_content'" >&2

            # Normalize whitespace for comparison
            promise_content=$(echo "$promise_content" | tr -s '[:space:]' ' ' | sed 's/^ *//;s/ *$//')
            completion_promise_normalized=$(echo "$completion_promise" | tr -s '[:space:]' ' ' | sed 's/^ *//;s/ *$//')

            # Use literal string comparison (not glob) to check for match
            if [[ -n "$promise_content" && "$promise_content" = "$completion_promise_normalized" ]]; then
                echo "Completion promise detected: $completion_promise" >&2
                echo "DEBUG: PPID=$PPID, sending SIGTERM" >&2
                rm -f "$STATE_FILE"

                # Force exit by sending SIGTERM to the Claude process
                # The hook runs as a child of Claude, so PPID is the Claude process
                # Use nohup to ensure the signal is sent even if this script exits
                # Small delay to allow this script to return cleanly first
                (sleep 0.5 && kill -TERM $PPID 2>/dev/null && echo "DEBUG: SIGTERM sent to $PPID" >&2) &

                echo '{"decision": "allow"}'
                exit 0
            fi
        fi
    fi
fi

# Extract the prompt (everything after the YAML frontmatter)
# First --- starts frontmatter, second --- ends it
prompt=$(sed '1,/^---$/d' "$STATE_FILE" | sed '1,/^---$/d')

# If no prompt found (malformed state file), allow exit
if [[ -z "$prompt" ]]; then
    echo "Error: No prompt found in state file" >&2
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# Increment iteration counter atomically using temp file + move
new_iteration=$((iteration + 1))
TEMP_FILE=$(mktemp)
sed "s/^iteration: *[0-9]*/iteration: $new_iteration/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build system message with iteration info and promise guidance
if [[ -n "$completion_promise" ]]; then
    system_message="Iteration $new_iteration of $max_iterations. Continue working on the task. When genuinely complete, output <promise>$completion_promise</promise> to exit the loop. Only output the promise when the task is truly finished."
else
    system_message="Iteration $new_iteration of $max_iterations. Continue working on the task."
fi

# Escape special characters in prompt for JSON
prompt_json=$(echo "$prompt" | jq -Rs .)

# Block exit and re-feed the prompt
cat << EOF
{
  "decision": "block",
  "reason": $prompt_json,
  "systemMessage": "$system_message"
}
EOF
