#!/bin/bash
#
# update-analytics.sh - Populate analytics from ground truth
#
# Called by run.sh and stop-hook.sh after sessions end.
# Reads git tags, task JSON, and commit history to fill analytics fields
# that the LLM was supposed to populate but didn't.
#
# Usage:
#   ./hooks/update-analytics.sh <analytics-file> <task-file> <session-start-epoch>
#
# Fields populated by this script:
#   Session: completedAt, summary stats
#   Per-requirement: id, description, status, startedAt (git tag),
#                    iterations (commits), filesWritten (git diff), stuckReason
#
# Fields left for LLM: errors[] array
# Fields left null: phases, toolCalls, filesRead (documented as optional)
#

set -euo pipefail

ANALYTICS_FILE="${1:-}"
TASK_FILE="${2:-}"
SESSION_START_EPOCH="${3:-}"

if [[ -z "$ANALYTICS_FILE" || -z "$TASK_FILE" ]]; then
    echo "Usage: update-analytics.sh <analytics-file> <task-file> <session-start-epoch>" >&2
    exit 1
fi

if [[ ! -f "$ANALYTICS_FILE" ]]; then
    echo "Analytics file not found: $ANALYTICS_FILE" >&2
    exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
    echo "Task file not found: $TASK_FILE" >&2
    exit 1
fi

# Require jq
if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed" >&2
    exit 1
fi

# Temp files for avoiding shell variable size limits
REQUIREMENTS_FILE=$(mktemp)
SUMMARY_FILE=$(mktemp)
trap 'rm -f "$REQUIREMENTS_FILE" "$SUMMARY_FILE"' EXIT

# --- Helper functions ---

# Get ISO8601 timestamp from epoch
epoch_to_iso() {
    date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
    date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
    echo ""
}

# Get epoch from a git tag (tag creation time)
tag_epoch() {
    local tag="$1"
    # Try annotated tag first, fall back to commit date
    git for-each-ref --format='%(creatordate:unix)' "refs/tags/$tag" 2>/dev/null | head -1
}

# Count commits between two refs
commit_count_between() {
    local from="$1"
    local to="${2:-HEAD}"
    git rev-list --count "$from".."$to" 2>/dev/null || echo "0"
}

# Get files changed between two refs
files_changed_between() {
    local from="$1"
    local to="${2:-HEAD}"
    git diff --name-only "$from".."$to" 2>/dev/null || true
}

# --- Pre-compute tag order ---
# Sort all autopilot/req-*/start tags by creation time so we can
# determine the correct upper bound (next tag) for each requirement.

declare -A TAG_UPPER_BOUND

build_tag_order() {
    local tag_list
    # Get all autopilot req tags sorted by creation time (oldest first)
    tag_list=$(git for-each-ref --sort=creatordate --format='%(refname:short)' 'refs/tags/autopilot/req-*/start' 2>/dev/null || true)

    if [[ -z "$tag_list" ]]; then
        return
    fi

    local prev_tag=""
    local tags=()
    while IFS= read -r tag; do
        tags+=("$tag")
    done <<< "$tag_list"

    # For each tag, the upper bound is the next tag in time order (or HEAD for the last)
    for i in "${!tags[@]}"; do
        local next_idx=$((i + 1))
        if [[ $next_idx -lt ${#tags[@]} ]]; then
            TAG_UPPER_BOUND["${tags[$i]}"]="${tags[$next_idx]}"
        else
            TAG_UPPER_BOUND["${tags[$i]}"]="HEAD"
        fi
    done
}

build_tag_order

# --- Read task file requirements ---

# Build requirements array from task JSON ground truth
# Writes result to $REQUIREMENTS_FILE as a JSON array
build_requirements() {
    local req_count
    req_count=$(jq '.requirements | length' "$TASK_FILE" 2>/dev/null || echo "0")

    if [[ "$req_count" -eq 0 ]]; then
        echo "[]" > "$REQUIREMENTS_FILE"
        return
    fi

    # Write each requirement as a separate JSON line to avoid shell variable limits
    local req_jsonl
    req_jsonl=$(mktemp)

    for i in $(seq 0 $((req_count - 1))); do
        local req_id req_desc req_passes req_stuck req_invalid req_blocked_reason
        req_id=$(jq -r ".requirements[$i].id // \"$((i+1))\"" "$TASK_FILE")
        req_desc=$(jq -r ".requirements[$i].description // \"\"" "$TASK_FILE")
        req_passes=$(jq -r ".requirements[$i].passes // false" "$TASK_FILE")
        req_stuck=$(jq -r ".requirements[$i].stuck // false" "$TASK_FILE")
        req_invalid=$(jq -r ".requirements[$i].invalidTest // false" "$TASK_FILE")
        req_blocked_reason=$(jq -r ".requirements[$i].blockedReason // empty" "$TASK_FILE" | tr -d '\n')

        # Determine status
        local status="pending"
        if [[ "$req_passes" == "true" ]]; then
            status="completed"
        elif [[ "$req_stuck" == "true" ]]; then
            status="stuck"
        elif [[ "$req_invalid" == "true" ]]; then
            status="invalid"
        fi

        # Check for git tag to get startedAt
        local start_tag="autopilot/req-${req_id}/start"
        local started_at="null"
        local iterations=0
        local files_written="[]"

        if git rev-parse "$start_tag" &>/dev/null; then
            local tag_time
            tag_time=$(tag_epoch "$start_tag")
            if [[ -n "$tag_time" && "$tag_time" != "0" ]]; then
                started_at="\"$(epoch_to_iso "$tag_time")\""
            fi

            # Use the next tag as upper bound instead of HEAD
            local upper_bound="${TAG_UPPER_BOUND[$start_tag]:-HEAD}"

            # Count commits as iteration proxy
            iterations=$(commit_count_between "$start_tag" "$upper_bound")

            # Get files changed in this requirement's range only
            local changed_files
            changed_files=$(files_changed_between "$start_tag" "$upper_bound")
            if [[ -n "$changed_files" ]]; then
                files_written=$(echo "$changed_files" | jq -R -s 'split("\n") | map(select(length > 0))')
            fi
        else
            # No tag = requirement was skipped or not started
            if [[ "$status" == "pending" ]]; then
                status="skipped"
            fi
        fi

        # Build stuck reason
        local stuck_reason="null"
        if [[ -n "$req_blocked_reason" ]]; then
            stuck_reason=$(echo "$req_blocked_reason" | jq -Rs '.')
        fi

        # Read existing errors from analytics (don't overwrite LLM-written fields)
        local existing_errors="[]"
        existing_errors=$(jq -r ".requirements[] | select(.id == \"$req_id\") | .errors // []" "$ANALYTICS_FILE" 2>/dev/null || echo "[]")
        if [[ -z "$existing_errors" || "$existing_errors" == "null" ]]; then
            existing_errors="[]"
        fi

        # Read existing thrashing data
        local existing_thrashing="null"
        existing_thrashing=$(jq -r ".requirements[] | select(.id == \"$req_id\") | .thrashing // null" "$ANALYTICS_FILE" 2>/dev/null || echo "null")
        if [[ -z "$existing_thrashing" ]]; then
            existing_thrashing="null"
        fi

        # Build requirement object and append to JSONL file
        jq -nc \
            --arg id "$req_id" \
            --arg desc "$req_desc" \
            --arg status "$status" \
            --argjson startedAt "$started_at" \
            --argjson iterations "$iterations" \
            --argjson filesWritten "$files_written" \
            --argjson stuckReason "$stuck_reason" \
            --argjson errors "$existing_errors" \
            --argjson thrashing "$existing_thrashing" \
            '{
                id: $id,
                description: $desc,
                status: $status,
                startedAt: $startedAt,
                completedAt: null,
                iterations: $iterations,
                phases: null,
                errors: $errors,
                thrashing: $thrashing,
                filesRead: null,
                filesWritten: $filesWritten,
                toolCalls: null,
                stuckReason: $stuckReason
            }' >> "$req_jsonl"
    done

    # Convert JSONL to JSON array via slurp
    jq -s '.' "$req_jsonl" > "$REQUIREMENTS_FILE"
    rm -f "$req_jsonl"
}

# --- Build summary ---

# Reads requirements from $REQUIREMENTS_FILE, writes summary to $SUMMARY_FILE
build_summary() {
    local actual_iterations="$1"

    local completed stuck invalid skipped
    completed=$(jq '[.[] | select(.status == "completed")] | length' "$REQUIREMENTS_FILE")
    stuck=$(jq '[.[] | select(.status == "stuck")] | length' "$REQUIREMENTS_FILE")
    invalid=$(jq '[.[] | select(.status == "invalid")] | length' "$REQUIREMENTS_FILE")
    skipped=$(jq '[.[] | select(.status == "skipped")] | length' "$REQUIREMENTS_FILE")

    # Estimate wasted iterations (stuck + thrashing iterations)
    local wasted=0
    local thrashing_iterations
    thrashing_iterations=$(jq '[.[] | select(.thrashing != null and .thrashing.detected == true) | .iterations] | add // 0' "$REQUIREMENTS_FILE")
    local stuck_iterations
    stuck_iterations=$(jq '[.[] | select(.status == "stuck") | .iterations] | add // 0' "$REQUIREMENTS_FILE")
    wasted=$((thrashing_iterations + stuck_iterations))

    # Efficiency score
    local efficiency="0"
    if [[ "$actual_iterations" -gt 0 ]]; then
        local productive=$((actual_iterations - wasted))
        if [[ $productive -lt 0 ]]; then productive=0; fi
        efficiency=$(echo "scale=2; $productive / $actual_iterations" | bc 2>/dev/null || echo "0")
    fi

    # Duration
    local duration_ms=0
    if [[ -n "$SESSION_START_EPOCH" && "$SESSION_START_EPOCH" =~ ^[0-9]+$ ]]; then
        local now
        now=$(date +%s)
        duration_ms=$(( (now - SESSION_START_EPOCH) * 1000 ))
    fi

    jq -n \
        --argjson completed "$completed" \
        --argjson stuck "$stuck" \
        --argjson invalid "$invalid" \
        --argjson skipped "$skipped" \
        --argjson totalIterations "$actual_iterations" \
        --argjson estimatedWastedIterations "$wasted" \
        --argjson efficiencyScore "$efficiency" \
        --argjson durationMs "$duration_ms" \
        '{
            completed: $completed,
            stuck: $stuck,
            invalid: $invalid,
            skipped: $skipped,
            totalIterations: $totalIterations,
            estimatedWastedIterations: $estimatedWastedIterations,
            efficiencyScore: $efficiencyScore,
            durationMs: $durationMs,
            patterns: []
        }' > "$SUMMARY_FILE"
}

# --- Main ---

# Read existing analytics to preserve LLM-written fields
existing_actual_iterations=$(jq '.actualIterations // 0' "$ANALYTICS_FILE" 2>/dev/null || echo "0")

# Build requirements from ground truth (writes to $REQUIREMENTS_FILE)
build_requirements

# Build summary (reads $REQUIREMENTS_FILE, writes to $SUMMARY_FILE)
build_summary "$existing_actual_iterations"

# Compute completedAt
completed_at="null"
if [[ -n "$SESSION_START_EPOCH" && "$SESSION_START_EPOCH" =~ ^[0-9]+$ ]]; then
    completed_at="\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\""
fi

# Merge into existing analytics file using --slurpfile to avoid argument size limits
TEMP_FILE=$(mktemp)
jq \
    --slurpfile requirements "$REQUIREMENTS_FILE" \
    --slurpfile summary "$SUMMARY_FILE" \
    --argjson completedAt "$completed_at" \
    '.requirements = $requirements[0] | .summary = $summary[0] | .completedAt = $completedAt' \
    "$ANALYTICS_FILE" > "$TEMP_FILE"

mv "$TEMP_FILE" "$ANALYTICS_FILE"

echo "Analytics updated: $ANALYTICS_FILE" >&2
