# Analyze

Analyze autopilot session analytics to identify waste patterns and generate improvement suggestions.

## Usage

```
/analyze                      # Analyze all sessions in analytics directory
/analyze --last               # Analyze only the most recent session
/analyze --since 7d           # Analyze sessions from last 7 days
/analyze --task user-auth     # Analyze sessions for specific task
/analyze --clear              # Delete all analytics files after review
```

## Overview

This command reads session analytics files from `docs/tasks/analytics/` and generates:
- Efficiency scores (productive vs wasted iterations)
- Detected waste patterns (thrashing, environment issues, etc.)
- Suggested improvements for AGENTS.md and autopilot.json
- Per-requirement breakdown of iterations and status

## Execution Steps

### 1. Parse Arguments

Extract from $ARGUMENTS:
- `--last`: Only analyze the most recent session file
- `--since Nd`: Filter to sessions from last N days (e.g., `7d`, `30d`)
- `--task NAME`: Filter to sessions matching task name pattern
- `--clear`: Delete analytics files after generating report

### 2. Load Analytics Files

1. Read analytics directory from `autopilot.json` (default: `docs/tasks/analytics/`)
2. List all `*.json` files in the directory
3. Apply filters based on arguments:
   - `--last`: Sort by date, take most recent
   - `--since`: Parse date from filename, filter by range
   - `--task`: Match task name in filename or `taskFile` field
4. Parse each matching JSON file

### 3. Aggregate Data

Combine data across all loaded sessions:

```json
{
  "sessionsAnalyzed": 5,
  "dateRange": { "start": "2026-01-03", "end": "2026-01-10" },
  "totals": {
    "iterations": 145,
    "completed": 12,
    "stuck": 3,
    "invalid": 1,
    "skipped": 2
  },
  "errors": [
    { "pattern": "ECONNREFUSED localhost:5432", "count": 25, "sessions": 3 },
    { "pattern": "Cannot find module 'foo'", "count": 4, "sessions": 1 }
  ],
  "thrashingEvents": [
    { "requirement": "2", "pattern": "connection_error", "count": 12 }
  ]
}
```

### 4. Identify Waste Patterns

Analyze aggregated data for common waste patterns:

**Environment Issues**
- Look for: `ECONNREFUSED`, `ETIMEOUT`, `Permission denied`, `sandbox`
- Suggested fix: Update sandbox settings in autopilot.json

**Thrashing**
- Look for: `thrashing.detected: true` in any requirement
- Suggested fix: Add pattern-specific handling to AGENTS.md

**Missing Context**
- Look for: "already exists", "duplicate", "not found" after creation attempt
- Suggested fix: Improve search-before-implement behavior

**Invalid Tests**
- Look for: `invalidTest: true` requirements
- Suggested fix: Better test writing guidance in prompts

**Dependency Issues**
- Look for: Stuck requirements with `dependsOn` where deps also stuck
- Suggested fix: Reorder requirements or resolve blocking issues

### 5. Calculate Efficiency Score

```
efficiency = (completed_iterations) / (total_iterations)

where:
  completed_iterations = sum of iterations for requirements with passes: true
  total_iterations = sum of all iterations
```

Breakdown waste by category:
- Thrashing iterations: count from thrashing.consecutiveCount
- Stuck iterations: iterations on requirements ending in stuck: true
- Invalid test iterations: iterations on requirements ending in invalidTest: true

### 6. Generate Report

Output a markdown report to console:

```markdown
# Autopilot Analysis Report

Generated: [ISO8601 timestamp]
Sessions analyzed: N
Date range: YYYY-MM-DD to YYYY-MM-DD

## Efficiency Score: XX%

Based on N iterations across M sessions:
- Productive iterations: X (Y%)
- Wasted iterations: Z (W%)

## Waste Breakdown

| Category | Iterations | % of Waste |
|----------|------------|------------|
| Thrashing | X | Y% |
| Environment issues | X | Y% |
| Stuck (non-thrashing) | X | Y% |
| Invalid tests | X | Y% |

## Waste Patterns Detected

### 1. [Pattern Name] (N iterations wasted)

**Pattern**: Description of what was detected

**Affected sessions**: List session filenames

**Suggested AGENTS.md entry**:
```
### [Category]
- YYYY-MM-DD: Description of learning
```

**Suggested autopilot.json change** (if applicable):
```json
{
  "key": "value"
}
```

[Repeat for each pattern...]

## Per-Requirement Breakdown

| Requirement | Sessions | Total Iter | Completed | Stuck | Waste |
|-------------|----------|------------|-----------|-------|-------|
| Description | N | X | Y | Z | W |

## Top Recommendations

1. **High Impact**: Description (saves ~N iterations/week)
2. **Medium Impact**: Description
3. **Low Impact**: Description

## Next Steps

1. Review suggestions above
2. Apply relevant changes to AGENTS.md
3. Update autopilot.json if needed
4. Run `/analyze --clear` to delete processed analytics files
```

### 7. Handle --clear Flag

If `--clear` was specified:
1. After displaying the report, prompt for confirmation
2. Delete all files in the analytics directory that were analyzed
3. Output: "Deleted N analytics files."

## Error Handling

- **No analytics files**: Output message suggesting running autopilot first
- **Invalid JSON**: Skip file, log warning, continue with others
- **Empty directory**: Output message that no sessions to analyze

## Notes

- This command only reads and reports; it never modifies AGENTS.md or autopilot.json
- Suggestions are formatted for easy copy-paste into the appropriate files
- Delete analytics files after applying learnings to avoid re-analyzing old data
