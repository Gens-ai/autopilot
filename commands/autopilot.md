# Autopilot

Start an autonomous work session with progress tracking and learnings.

## Overview

This prompt is structured in phases:
- **Phase 0**: Pre-flight checks and argument parsing
- **Phase 1-8**: Mode-specific execution
- **Phase 99999+**: Critical guardrails (highest priority, read last for maximum attention)

## Usage

```
/autopilot init                             # Initialize project configuration
/autopilot stop                             # Stop run.sh loop gracefully
/autopilot cancel                           # Cancel hook-based loop
/autopilot <file.json> [max-iterations]    # TDD task completion mode (default)
/autopilot tests [target%] [max-iterations] # Test coverage mode
/autopilot lint [max-iterations]            # Linting mode
/autopilot entropy [max-iterations]         # Code cleanup mode
```

Default max-iterations are configured in `autopilot.json` (tasks: 15, tests: 10, lint: 15, entropy: 10). Pass a number to override. Lower defaults optimize for token frugality - restart sessions frequently for fresh context.

**Iteration Expectations:**
| Mode | Default | Per Item | Typical Session |
|------|---------|----------|-----------------|
| tasks | 15 | 3-5 iterations/requirement | 3-5 requirements |
| tests | 10 | 2-3 iterations/test | 3-5 tests |
| lint | 15 | 1-2 iterations/fix | 10-15 fixes |
| entropy | 10 | 2-3 iterations/cleanup | 3-5 cleanups |

For larger task files, increase iterations or use `--start-from` to resume across sessions.

## Phase 0: Pre-flight

### 0a. Configuration Check

**Before executing any mode, check for `autopilot.json` in the project root.**

### If `autopilot.json` does not exist:

Tell the user:
```
Autopilot is not configured for this project.

Run /autopilot init to set up autopilot with:
- Feedback loop detection (tests, lint, typecheck)
- Project type and conventions
- Iteration limits per mode
- Server configuration

This only needs to be done once per project.

Quick setup: /autopilot init --force (uses auto-detected values)
```

Then stop execution. Do not proceed without configuration.

### If `autopilot.json` exists but has null required values:

Check these required fields:
- `project.type` - must not be null
- `feedbackLoops.tests.command` - must not be null (unless `enabled: false`)
- `feedbackLoops.lint.command` - must not be null (unless `enabled: false`)

If any required fields are null, tell the user:
```
Autopilot configuration is incomplete.

Missing fields:
- <list missing fields with descriptions>

How to fix:
1. Run /autopilot init to re-detect and fill missing values
2. Or manually edit autopilot.json:
   - project.type: Your project language (nodejs, python, go, etc.)
   - feedbackLoops.tests.command: Command to run tests (e.g., "npm test")
   - feedbackLoops.lint.command: Command to run linter (e.g., "npm run lint")

If you don't have tests or linting, set enabled: false for that feedback loop.
```

Then stop execution.

### If `autopilot.json` is valid:

Read the configuration and use:
- `iterations.tasks`, `iterations.tests`, `iterations.lint`, `iterations.entropy` as default max iterations
- `feedbackLoops.typecheck.command`, `feedbackLoops.tests.command`, `feedbackLoops.lint.command` for pre-commit checks
- `project.conventions.testFilePattern` and `project.conventions.testDirectory` for test locations

Proceed to argument parsing and mode execution.

### 0b. Argument Parsing

Parse `$ARGUMENTS` to extract:
1. **Mode** - Determined by first argument (`init`, file path, `tests`, `lint`, or `entropy`)
2. **Max iterations** - Optional trailing number (defaults from autopilot.json)
3. **Mode-specific params** - Target percentage for tests mode, file path for TDD mode
4. **--start-from ID** - Optional flag to resume from a specific requirement ID (TDD mode only)
5. **--batch N** - Complete N requirements then stop (TDD mode only, default: all)

Examples:
- `/autopilot init` → Run initialization wizard
- `/autopilot init --force` → Run initialization with auto-detected values
- `/autopilot tasks.json` → TDD mode, iterations from config (default: 15)
- `/autopilot tasks.json 30` → TDD mode, 30 iterations
- `/autopilot tasks.json --start-from 5` → TDD mode, skip requirements before ID 5
- `/autopilot tasks.json --start-from 5 30` → TDD mode, start from 5, 30 iterations
- `/autopilot tasks.json --batch 1` → TDD mode, complete 1 requirement then stop
- `/autopilot tasks.json --batch 3` → TDD mode, complete up to 3 requirements then stop
- `/autopilot tests 80` → Test mode, 80% target, iterations from config (default: 10)
- `/autopilot tests 80 15` → Test mode, 80% target, 15 iterations
- `/autopilot lint 10` → Lint mode, 10 iterations

### 0c. Mode Detection

Based on the argument ($ARGUMENTS), determine the mode:

1. **If argument is `init`** → Run `/autopilot init` command (invoke the init.md command)
2. **If argument is `stop`** → Stop mode (signal run.sh to exit)
3. **If argument is `cancel`** → Cancel mode (remove loop state file)
4. **If argument ends with `.json` or `.md`** → TDD task completion mode
5. **If argument starts with `tests`** → Test coverage mode
6. **If argument starts with `lint`** → Linting mode
7. **If argument starts with `entropy`** → Entropy/cleanup mode
8. **If argument starts with `rollback`** → Rollback mode
9. **If argument is `metrics`** → Metrics report mode
10. **If argument is `analyze`** → Session analytics mode

### 0d. Analytics Initialization

If analytics are enabled in `autopilot.json` (default: true), initialize session analytics before running any mode that uses iterations (tasks, tests, lint, entropy).

**Steps:**

1. **Read analytics config** from `autopilot.json`:
   - `analytics.enabled` (default: true)
   - `analytics.directory` (default: `docs/tasks/analytics`)
   - `analytics.thrashingThreshold` (default: 3)

2. **Create analytics directory** if it doesn't exist

3. **Generate session file name**: `YYYY-MM-DD-TASKNAME-N.json`
   - TASKNAME: derived from task file name or mode (e.g., `user-auth` from `user-auth.json`, or `lint-session`)
   - N: incrementing number if multiple sessions same day (1, 2, 3...)
   - Example: `2026-01-10-user-auth-1.json`

4. **Initialize analytics file** with base structure:
   ```json
   {
     "$schema": "https://raw.githubusercontent.com/Gens-ai/autopilot/main/analytics.schema.json",
     "sessionId": "<timestamp-based-id>",
     "startedAt": "<ISO8601>",
     "completedAt": null,
     "taskFile": "<path or mode name>",
     "mode": "<tasks|tests|lint|entropy>",
     "maxIterations": <N>,
     "actualIterations": 0,
     "requirements": [],
     "summary": null
   }
   ```

5. **Store path** as `ANALYTICS_FILE` for use during execution

---

## Phase 1: Mode Execution

### Mode: Init

For `init` argument, invoke the `/autopilot init` command to run the initialization wizard.

Pass any additional arguments (like `--force`, `--skip-validation`) to the init command.

## Mode: Stop

For `stop` argument. Signals the run.sh loop to exit gracefully.

**Do not check for autopilot.json** - this mode should work regardless of configuration.

Steps:
1. Check if `.autopilot.pid` exists
2. If it does not exist, tell the user:
   ```
   No autopilot session is running.
   ```
3. If it exists, read the PID from the file
4. Check if the process is running: `kill -0 $PID 2>/dev/null`
5. If process is not running, remove the stale PID file and tell the user:
   ```
   No autopilot session is running (removed stale PID file).
   ```
6. If process is running, send SIGUSR1: `kill -USR1 $PID`
7. Tell the user:
   ```
   Stop signal sent to autopilot (PID $PID). The session will terminate shortly.
   ```

## Mode: Cancel

For `cancel` argument. Cancels an active hook-based loop by removing the state file.

**Do not check for autopilot.json** - this mode should work regardless of configuration.

Steps:
1. Check if `.autopilot/loop-state.md` exists
2. If it does not exist, tell the user:
   ```
   No active autopilot loop found.

   If you're trying to stop the run.sh wrapper, use:
     /autopilot stop
   Or press Ctrl+C in the terminal running the wrapper.
   ```
3. If it exists, read the current iteration from the YAML frontmatter
4. Delete the file: `rm .autopilot/loop-state.md`
5. Tell the user:
   ```
   Autopilot loop canceled at iteration N.

   The loop will exit on the next iteration attempt.
   Note: Any work in progress will complete before the loop stops.
   ```

## Mode: TDD Task Completion (default)

For file paths (`.json` or `.md` files). Uses Test-Driven Development.

Read `autopilot.json` to get:
- `TYPECHECK_CMD` from `feedbackLoops.typecheck.command` (if enabled)
- `TEST_CMD` from `feedbackLoops.tests.command`
- `LINT_CMD` from `feedbackLoops.lint.command`
- `MAXITER` default from `iterations.tasks` (usually 15)

Check for `--start-from ID` flag. If present, extract the START_ID.
Check for `--batch N` flag. If present, extract the BATCH_COUNT (default: 0 means unlimited).

### Loop Setup

Create the loop state file `.autopilot/loop-state.md` with YAML frontmatter:

```markdown
---
iteration: 1
max_iterations: MAXITER
completion_promise: COMPLETE
---

Complete requirements in TASKFILE using TDD.

BATCH_INSTRUCTION

Read TASKFILE-notes.md if it exists or create it with initial state template.
Read AGENTS.md Learnings section for relevant prior learnings about this codebase.

START_FROM_INSTRUCTION

Skip requirements with passes true or invalidTest true or stuck true.
Also skip requirements with dependsOn where any dependency has passes false.

ANALYTICS_INSTRUCTION

For each workable incomplete requirement:
1. First create git tag autopilot/req-ID/start
2. Track files you modify
3. If requirement has a package field then use that package feedback loop commands from workspaces config
4. If requirement has an issue field then append issue reference to commit messages

TDD Cycle:
- RED: Write failing test and run TEST_CMD and VERIFY TEST FAILS
  - If test passes before implementation then mark invalidTest true with invalidTestReason and skip to next
  - Only after confirming test failure then commit and proceed to implementation
- GREEN: Write minimal implementation and run TEST_CMD to confirm pass then commit
- REFACTOR: Run code-simplifier on ONLY the files you modified for this requirement then run TYPECHECK_CMD and TEST_CMD and LINT_CMD to verify green then commit

Mark tdd phases as you complete each.
Mark requirement passes true when all three phases done.
Run feedback loops before committing. Do NOT commit if any fail.

THRASHING_INSTRUCTION

If same task fails 3 iterations then add stuck true with blockedReason and ADD A LEARNING to AGENTS.md under the appropriate category explaining what blocked you and note that rollback is available with /autopilot rollback ID and log blocker to notes and skip to next.

Update TASKFILE-notes.md after each requirement with Current State section and list files modified for this requirement.

COMPLETION_INSTRUCTION
```

Replace:
- ANALYTICS_INSTRUCTION with `If analytics enabled then update ANALYTICS_FILE with requirement start time and increment actualIterations after each iteration and log errors with type and message to the requirement errors array and track filesRead and filesWritten.` if analytics are enabled, otherwise remove it
- THRASHING_INSTRUCTION with `Track consecutive identical errors. If the same error pattern appears THRASHING_THRESHOLD times in a row then immediately mark stuck with blockedReason containing Thrashing detected and the error pattern and set thrashing.detected true in analytics.` where THRASHING_THRESHOLD comes from autopilot.json analytics.thrashingThreshold (default: 3)
- TASKFILE with the provided file path
- MAXITER with the provided number or default from `iterations.tasks`
- TYPECHECK_CMD, TEST_CMD, LINT_CMD with commands from autopilot.json (omit if disabled)
- START_FROM_INSTRUCTION with `Skip requirements with id less than START_ID.` if --start-from was specified, otherwise remove it
- BATCH_INSTRUCTION with `Stop after completing BATCH_COUNT requirements and output COMPLETE.` if --batch was specified, otherwise remove it
- COMPLETION_INSTRUCTION with `Output COMPLETE after completing BATCH_COUNT requirements.` if --batch was specified, otherwise `Output COMPLETE when all requirements pass or all remaining are stuck or invalid or blocked by dependencies.`

### Execution

After creating the loop state file, execute the TDD cycle directly. The stop-hook will intercept exit attempts and re-feed the prompt for subsequent iterations until COMPLETE is output or max iterations reached.

## Mode: Rollback

For `rollback <requirement-id>` arguments. Rolls back to the state before a specific requirement was started.

Usage: `/autopilot rollback 5` - rolls back to before requirement 5 was started

Steps:
1. Find the git tag `autopilot/req-{id}/start` for the specified requirement
2. If tag exists, run `git reset --hard autopilot/req-{id}/start`
3. Delete any tags created after this point
4. Update the task JSON to reset the requirement and any subsequent requirements to `passes: false`

**Warning**: This is a destructive operation. All commits after the tag will be lost.

## Mode: Metrics

For `metrics` argument. Generates an aggregated metrics report across all autopilot sessions.

**Note:** This is an alias for `/autopilot analyze` with aggregation focus. Both commands read the same analytics data.

Usage:
```
/autopilot metrics                    # Show aggregated metrics across all sessions
/autopilot metrics --since 30d        # Metrics from last 30 days
```

Redirect to analyze mode with appropriate messaging:
1. Tell the user: "Generating metrics report..."
2. Execute the analyze command logic (see Mode: Analyze below)
3. Focus output on aggregated statistics rather than per-session suggestions

## Mode: Analyze

For `analyze` argument. Reads session analytics files and generates improvement suggestions.

Usage:
```
/autopilot analyze                    # Analyze all sessions in analytics directory
/autopilot analyze --last             # Analyze only the most recent session
/autopilot analyze --since 7d         # Analyze sessions from last 7 days
/autopilot analyze --task user-auth   # Analyze sessions for specific task
```

### Analysis Steps

1. **Read analytics directory** from `autopilot.json` (default: `docs/tasks/analytics/`)

2. **Load session files** matching the filter criteria

3. **Aggregate data** across sessions:
   - Total iterations used
   - Estimated wasted iterations (thrashing + stuck)
   - Success rate (completed / total attempted)
   - Common error patterns
   - Frequently stuck requirements

4. **Identify waste patterns**:
   - **Thrashing**: Same error appearing 3+ times consecutively
   - **Environment issues**: Connection refused, permission denied, sandbox blocks
   - **Missing context**: Errors that codebase search could have prevented
   - **Invalid tests**: Tests that passed before implementation

5. **Generate suggestions** (output to console, not auto-applied):

```markdown
# Autopilot Analysis Report

Generated: 2026-01-10T15:30:00Z
Sessions analyzed: 5
Date range: 2026-01-03 to 2026-01-10

## Efficiency Score: 72%

Based on 145 iterations across 5 sessions:
- Productive iterations: 104 (72%)
- Wasted iterations: 41 (28%)

## Waste Patterns Detected

### 1. Environment/Sandbox Issues (25 iterations wasted)

**Pattern**: `ECONNREFUSED localhost:5432` appeared 25 times across 3 sessions

**Suggested AGENTS.md entry**:
```
### Gotchas
- 2026-01-10: Database tests require sandbox: false. If you see ECONNREFUSED localhost:5432, check autopilot.json feedbackLoops.tests.sandbox setting before retrying.
```

**Suggested autopilot.json change**:
```json
"feedbackLoops": {
  "tests": {
    "sandbox": false
  }
}
```

### 2. Thrashing on Test Assertions (12 iterations wasted)

**Pattern**: Same assertion failure in `auth.test.ts` repeated 12 times

**Suggested AGENTS.md entry**:
```
### Testing
- 2026-01-10: When test assertions fail repeatedly, re-read the requirement and acceptance criteria. The test may be checking the wrong thing.
```

### 3. Missing Codebase Context (4 iterations wasted)

**Pattern**: Created duplicate utility function that already existed in `src/lib/utils.ts`

**Suggested AGENTS.md entry**:
```
### Patterns
- 2026-01-10: Always search for existing utilities before creating new ones. Check src/lib/ directory first.
```

## Per-Requirement Breakdown

| Requirement | Iterations | Status | Waste |
|-------------|------------|--------|-------|
| 1: User model | 4 | completed | 0 |
| 2: Registration | 15 | stuck | 12 (thrashing) |
| 3: Login | 6 | completed | 1 |
| 4: Password reset | 8 | completed | 2 |

## Recommendations

1. **High Impact**: Add `sandbox: false` to tests feedback loop (saves ~25 iterations/week)
2. **Medium Impact**: Add thrashing pattern for ECONNREFUSED to known issues
3. **Low Impact**: Improve codebase search before implementing utilities

## Next Steps

Review these suggestions and:
1. Apply relevant changes to AGENTS.md
2. Update autopilot.json if needed
3. Delete this analytics file after applying learnings

Run `/autopilot analyze --clear` to delete all processed analytics files.
```

### Analysis Output

The analysis is printed to console as markdown for easy reading. Suggestions are NOT automatically applied - you review and apply them manually to maintain control over the autopilot configuration.

After reviewing and applying suggestions, delete the analytics files:
```bash
rm docs/tasks/analytics/*.json
```

Or use `/autopilot analyze --clear` to delete all analytics files after reviewing.

## Mode: Test Coverage

For `tests` or `tests <target%>` arguments.

Read `autopilot.json` to get:
- `TEST_CMD` from `feedbackLoops.tests.command`
- `MAXITER` default from `iterations.tests` (usually 10)
- Coverage targeting options from `coverage` config

### Loop Setup

Create the loop state file `.autopilot/loop-state.md` with YAML frontmatter:

```markdown
---
iteration: 1
max_iterations: MAXITER
completion_promise: COMPLETE
---

Increase test coverage to TARGET percent minimum.

Read docs/tasks/test-coverage-notes.md if it exists or create it with initial state template.

Run coverage report.

Prioritize uncovered code in this order:
1. Recently changed files from git log last 30 days
2. Critical paths like auth and payments and error handling
3. High complexity functions
4. Remaining uncovered lines

Exclude files matching coverage.exclude patterns.

Write tests for highest priority uncovered paths first.
Run TEST_CMD to verify pass.
Run coverage to verify improvement.

If no coverage increase after 3 iterations then log blocker to notes and output COMPLETE with current coverage.

Update notes with Current State section.
Log learnings to AGENTS.md.
Commit after each test passes.

Output COMPLETE when target reached or stuck.
```

Replace:
- TARGET with the provided percentage (default: 80)
- MAXITER with the provided number or default from `iterations.tests`
- TEST_CMD with command from autopilot.json

### Execution

After creating the loop state file, execute the coverage improvement cycle directly. The stop-hook handles iteration.

## Mode: Linting

For `lint` argument.

Read `autopilot.json` to get:
- `LINT_CMD` from `feedbackLoops.lint.command`
- `MAXITER` default from `iterations.lint` (usually 15)

### Loop Setup

Create the loop state file `.autopilot/loop-state.md` with YAML frontmatter:

```markdown
---
iteration: 1
max_iterations: MAXITER
completion_promise: COMPLETE
---

Fix lint errors one at a time.

Read docs/tasks/lint-fixes-notes.md if it exists or create it with initial state template.

Run LINT_CMD.

Fix ONE error at a time.
Run LINT_CMD to verify fix.
Do not batch fixes.

If same error fails 3 attempts then log to notes with details and skip to next.

Update notes with Current State section.
Log learnings to AGENTS.md.
Commit after each fix passes.

Output COMPLETE when no errors remain or only stuck errors.
```

Replace:
- MAXITER with the provided number or default from `iterations.lint`
- LINT_CMD with command from autopilot.json

### Execution

After creating the loop state file, execute the lint fix cycle directly. The stop-hook handles iteration.

## Mode: Entropy

For `entropy` argument.

Read `autopilot.json` to get:
- `TYPECHECK_CMD` from `feedbackLoops.typecheck.command` (if enabled)
- `TEST_CMD` from `feedbackLoops.tests.command`
- `LINT_CMD` from `feedbackLoops.lint.command`
- `MAXITER` default from `iterations.entropy` (usually 10)

### Loop Setup

Create the loop state file `.autopilot/loop-state.md` with YAML frontmatter:

```markdown
---
iteration: 1
max_iterations: MAXITER
completion_promise: COMPLETE
---

Clean up code entropy.

Read docs/tasks/entropy-cleanup-notes.md if it exists or create it with initial state template.

Run code-simplifier on recent files.

Scan for code smells like:
- Unused exports
- Dead code
- Inconsistent patterns
- Duplicates
- Complex functions

Fix ONE issue at a time.
Run TYPECHECK_CMD and TEST_CMD and LINT_CMD after each fix.
Do NOT commit if any fail.

If same issue fails 3 attempts then log to notes and move on.

Update notes with Current State section.
Log learnings to AGENTS.md.
Commit after each fix passes.

Output COMPLETE when no smells remain or only stuck issues.
```

Replace:
- MAXITER with the provided number or default from `iterations.entropy`
- TYPECHECK_CMD, TEST_CMD, LINT_CMD with commands from autopilot.json (omit if disabled)

### Execution

After creating the loop state file, execute the entropy cleanup cycle directly. The stop-hook handles iteration.

## Stuck Handling

All modes include stuck handling to prevent infinite loops on intractable problems:

1. **Detection**: Same task/error failing for 3 consecutive iterations
2. **Action**: Log the blocker with details to the notes file
3. **Recovery**: Mark as stuck, skip to next task, continue working
4. **Completion**: Output COMPLETE when done or only stuck items remain

This ensures autopilot makes progress even when some tasks are blocked.

## Thrashing Detection

**Thrashing** occurs when the same error repeats without meaningful progress. This wastes tokens and indicates a fundamental blocker that retrying won't solve.

### How Thrashing Detection Works

1. **Track consecutive errors**: For each requirement, maintain a list of recent error messages
2. **Normalize errors**: Strip variable parts (timestamps, line numbers, UUIDs) to compare error patterns
3. **Detect repetition**: If the same normalized error appears N times consecutively (default: 3, configurable via `analytics.thrashingThreshold`)
4. **Abort early**: Immediately mark the requirement as `stuck` with `blockedReason: "Thrashing detected: <pattern>"`

### Common Thrashing Patterns

| Pattern | Likely Cause | Suggested Fix |
|---------|--------------|---------------|
| `ECONNREFUSED localhost:*` | Sandbox blocking ports | Set `sandbox: false` in feedback loop |
| `Cannot find module` | Missing dependency | Check package.json, run npm install |
| `ETIMEOUT` | Network/service unavailable | Check if external service is running |
| `Permission denied` | File/directory permissions | Check ownership, sandbox restrictions |
| Same test assertion failing | Logic error or misunderstanding | Re-read requirement, check assumptions |

### Analytics Integration

When thrashing is detected:

1. **Log to analytics file**:
   ```json
   {
     "thrashing": {
       "detected": true,
       "pattern": "ECONNREFUSED localhost:5432",
       "consecutiveCount": 5,
       "aborted": true
     }
   }
   ```

2. **Update notes file** with thrashing details for human review

3. **Add to session summary** under waste patterns

### Thrashing vs Regular Stuck

- **Regular stuck**: Tried 3 different approaches, none worked
- **Thrashing**: Same exact error 3+ times, no progress

Thrashing aborts faster because retrying the identical action is definitionally wasteful. Regular stuck handling allows for trying different approaches before giving up.

## Completion Summary

When autopilot finishes - whether all requirements pass or session ends - generate a completion summary. Save it to `TASKFILE-summary.md` alongside the notes file.

**Summary format:**

```markdown
# Autopilot Session Summary

## Results
- Completed: X requirements
- Stuck: Y requirements
- Invalid tests: Z requirements
- Remaining: N requirements

## Completed Requirements
- [1] Description of requirement 1
- [3] Description of requirement 3

## Stuck Requirements
- [2] Description - Reason: blockedReason from JSON

## Commits Made
- abc1234 Commit message 1
- def5678 Commit message 2

## Files Modified
- path/to/file1.ts
- path/to/file2.ts

## Next Steps
- Resume with: /autopilot TASKFILE --start-from X
- Review stuck items and update requirements if needed
```

The summary provides:
- Quick visibility into session results
- List of commits for review
- Clear next steps for continuation

## Monorepo and Workspace Support

Autopilot supports monorepos with multiple packages. Configure workspaces in autopilot.json:

```json
{
  "workspaces": {
    "enabled": true,
    "packages": {
      "api": {
        "path": "packages/api",
        "feedbackLoops": {
          "tests": { "command": "npm test --workspace=api" },
          "lint": { "command": "npm run lint --workspace=api" }
        }
      },
      "web": {
        "path": "packages/web",
        "feedbackLoops": {
          "tests": { "command": "npm test --workspace=web" },
          "lint": { "command": "npm run lint --workspace=web" }
        }
      }
    }
  }
}
```

**Scoping requirements to packages:**

In your task JSON, add a `package` field to requirements:

```json
{
  "id": "5",
  "description": "Add user authentication",
  "package": "api"
}
```

When a requirement specifies a package:
- Use that package's feedback loop commands instead of root commands
- Run commands from the package path
- Track files relative to the package

**Auto-detection:**

Autopilot can detect monorepo structures during `/autopilot init`:
- npm/yarn/pnpm workspaces via package.json
- Lerna via lerna.json
- Nx via nx.json
- Turborepo via turbo.json

## Issue Tracker Integration

Autopilot can link work to GitHub Issues or other trackers. Configure in autopilot.json:

```json
{
  "issueTracker": {
    "type": "github",
    "linkCommits": true,
    "updateOnComplete": true,
    "labelOnStart": "in-progress",
    "labelOnComplete": "done"
  }
}
```

**Linking issues to requirements:**

In your task JSON, add an `issue` field to requirements:

```json
{
  "id": "5",
  "description": "Add user authentication",
  "issue": "#123"
}
```

**Commit message linking:**

When `linkCommits: true`, autopilot will append issue references to commit messages:
- `feat: Add login form (#123)`

**Issue updates:**

When `updateOnComplete: true`, autopilot will comment on the issue when the requirement passes:
- Adds a comment summarizing the commits
- Changes label from `labelOnStart` to `labelOnComplete`

**Creating tasks from issues:**

Use `/prd` with a GitHub issue URL to generate a PRD from the issue:
```
/prd https://github.com/owner/repo/issues/123
```

This fetches the issue description and comments to seed the PRD clarifying questions.

## Notifications

Configure notifications in autopilot.json to be alerted when autopilot completes:

```json
{
  "notifications": {
    "enabled": true,
    "command": "notify-send 'Autopilot' 'Session complete'",
    "webhook": "https://hooks.example.com/autopilot",
    "ntfy": {
      "topic": "my-autopilot",
      "server": "https://ntfy.sh"
    }
  }
}
```

**Options:**
- `command`: Shell command to run. Use for desktop notifications like `notify-send` or `say`
- `webhook`: URL to POST results JSON to. Works with Slack, Discord, or custom endpoints
- `ntfy`: ntfy.sh push notification. Just set a topic name to receive on your phone

At least one notification method should be configured if `enabled: true`.

## Auto-Documentation

Autopilot can automatically update documentation after completing requirements. Configure in autopilot.json:

```json
{
  "documentation": {
    "enabled": true,
    "changelog": {
      "file": "CHANGELOG.md",
      "format": "keepachangelog"
    },
    "readme": {
      "enabled": false,
      "sections": ["features", "usage"]
    }
  }
}
```

**Changelog generation:**

When enabled, autopilot adds entries to your changelog after completing requirements:

```markdown
## [Unreleased]

### Added
- User authentication with email/password (#101)
- Google OAuth login support (#102)

### Fixed
- Password reset token expiration (#103)
```

Supported formats:
- `keepachangelog` - Keep a Changelog format (default)
- `conventional` - Conventional Commits style

**README updates:**

When `readme.enabled: true`, autopilot can update specified sections of your README based on completed features. Use with caution - review changes before committing.

**Per-requirement control:**

Add `skipDocs: true` to individual requirements to skip documentation for that item:

```json
{
  "id": "5",
  "description": "Internal refactor",
  "skipDocs": true
}
```

## Metrics and Analytics

Autopilot can track metrics across sessions to help identify patterns and improve effectiveness. Configure in autopilot.json:

```json
{
  "metrics": {
    "enabled": true,
    "file": "docs/tasks/autopilot-metrics.json"
  }
}
```

**Tracked metrics:**
- Success rate: completed vs stuck requirements
- Average time per requirement
- Common stuck reasons (aggregated from blockedReason fields)
- Frequently modified files
- Iterations per requirement

**Metrics file format:**

```json
{
  "sessions": [
    {
      "date": "2026-01-09",
      "taskFile": "docs/tasks/prds/user-auth.json",
      "completed": 5,
      "stuck": 1,
      "invalid": 0,
      "totalIterations": 18,
      "duration": "45m"
    }
  ],
  "aggregates": {
    "totalCompleted": 42,
    "totalStuck": 3,
    "successRate": 0.93,
    "avgIterationsPerRequirement": 3.2,
    "commonStuckReasons": [
      { "reason": "flaky test", "count": 2 },
      { "reason": "missing dependency", "count": 1 }
    ],
    "frequentlyModifiedFiles": [
      { "file": "src/auth/login.ts", "count": 8 },
      { "file": "src/utils/validation.ts", "count": 5 }
    ]
  }
}
```

**Viewing metrics:**

Run `/autopilot metrics` to generate a summary report of your autopilot usage patterns.

## Resume Workflow

To resume an interrupted autopilot session:

1. **Check the notes file** (`TASKFILE-notes.md`) to see current state
2. **Find the next requirement ID** from "Working on" or check the JSON for first non-passing requirement
3. **Resume with --start-from**: `/autopilot TASKFILE --start-from ID`

The `--start-from` flag skips all requirements with IDs less than the specified ID. This is useful when:
- A session was interrupted and you want to continue
- You want to re-run from a specific requirement after fixing issues
- Some early requirements are already complete from a previous run

Note: Requirements with `passes: true`, `stuck: true`, or `invalidTest: true` are always skipped regardless of --start-from.

## Code Simplifier

The `code-simplifier` agent simplifies code for clarity and maintainability while preserving functionality. Use it via the Task tool with `subagent_type: code-simplifier`.

When to run:
- **TDD Refactor phase**: After implementation passes tests, before committing refactor
- **Entropy mode**: At the start of each iteration on recently modified files

### File Tracking for Code Simplifier

Track files modified during each requirement to pass explicitly to code-simplifier:

1. **Before starting a requirement**: Note which files exist
2. **During implementation**: Track new files created and existing files modified
3. **At refactor phase**: Pass only the tracked file list to code-simplifier

Example tracking in notes:
```markdown
### Requirement 5 Files
- src/auth/login.ts (modified)
- src/auth/types.ts (new)
- tests/auth/login.test.ts (new)
```

When invoking code-simplifier, pass the explicit file list:
```
Run code-simplifier on these files: src/auth/login.ts, src/auth/types.ts, tests/auth/login.test.ts
```

This avoids running code-simplifier on untouched files and keeps refactoring focused.

## TDD Rules (Task Completion Mode)

1. **Red**: Write tests covering ALL acceptance criteria, run tests, VERIFY they FAIL
   - Read the `acceptance` array - each criterion becomes a test case
   - Write tests that will fail until the implementation is complete
   - If any test passes before implementation, the test is invalid
   - Mark the requirement as `invalidTest: true` with reason and skip to next
   - Only proceed to Green phase after confirming ALL tests fail
2. **Green**: Write minimal code to make ALL tests pass
   - Implement just enough to satisfy each acceptance criterion
   - Do not over-engineer or add unrequested features
3. **Refactor**: Run code-simplifier, then verify tests still green
4. **Never skip**: All three phases required for each requirement
5. **One at a time**: Complete full TDD cycle before next requirement

### Acceptance-Driven Testing

The `acceptance` array defines what "done" means. Each criterion must have a corresponding test:

```json
"acceptance": [
  "Reset email sent within 5 seconds",    // → test: should send email within timeout
  "Token expires after 1 hour",           // → test: should reject expired tokens
  "Used token cannot be reused"           // → test: should reject already-used tokens
]
```

Before marking `tdd.test.passes: true`, verify you have tests covering ALL acceptance criteria.

### Requirement Dependencies

Requirements can specify a `dependsOn` field to declare dependencies on other requirements:

```json
{
  "id": "5",
  "description": "Add user profile API",
  "dependsOn": ["2", "3"]
}
```

**How dependencies work:**
- A requirement with `dependsOn` will be skipped until all listed requirement IDs have `passes: true`
- Independent requirements (no `dependsOn` or empty array) can be worked on in any order
- Circular dependencies are invalid and will be flagged

**Identifying independent requirements:**
- Requirements that touch different subsystems or files
- Features that do not share test fixtures or database state
- Changes that will not conflict when merged

**Parallel execution with multiple instances:**
1. Split independent requirements into separate task files
2. Create a branch for each task file: `git checkout -b autopilot/task-a`
3. Run autopilot on each branch in separate terminals
4. Merge branches when complete: `git merge autopilot/task-a autopilot/task-b`

Alternatively, identify a set of independent requirements and run them on a single branch in one session - autopilot will work through them sequentially but you avoid branch management.

### Test Types

Requirements can specify a `testType` field to use different test commands:
- `unit` - Fast, isolated unit tests (default)
- `integration` - Tests that involve multiple components or external services
- `e2e` - End-to-end tests using browser automation or full system tests

Configure test commands per type in autopilot.json:

```json
{
  "feedbackLoops": {
    "tests": {
      "command": "npm test",
      "commands": {
        "unit": "npm test -- --testPathPattern=unit",
        "integration": "npm test -- --testPathPattern=integration",
        "e2e": "npm run test:e2e"
      }
    }
  }
}
```

In requirement JSON, specify the test type:
```json
{
  "id": "5",
  "testType": "integration",
  "description": "Add user authentication API"
}
```

If no `testType` is specified, use the default `command`. If `testType` is specified but no matching command exists, fall back to the default.

### Invalid Test Detection

A test that passes before implementation indicates one of:
- The feature already exists
- The test is not actually testing the new behavior
- The test has a bug that makes it always pass

When this happens:
- Do NOT proceed with implementation
- Mark requirement with `invalidTest: true` and `invalidTestReason: "..."`
- Log the issue to notes file
- Skip to next requirement

## Common Behaviors (All Modes)

- Read feedback loop commands from `autopilot.json`
- Before committing, run enabled feedback loops: typecheck, tests, lint
- Do NOT commit if any feedback loop fails - fix first
- Skip disabled feedback loops (where `enabled: false`)
- Check `sandbox` setting for each feedback loop - if `sandbox: false`, use `dangerouslyDisableSandbox: true` when running the command via Bash tool
- Log mistakes or learnings to AGENTS.md
- Keep changes small and focused (one logical change per commit)
- After 3 failed attempts on same issue, mark stuck and move on

### Feedback Loop Execution

Run feedback loops **sequentially** with fail-fast behavior:

1. Run typecheck command (if enabled)
   - If it fails, stop and fix before continuing
2. Run test command (if enabled)
   - If it fails, stop and fix before continuing
3. Run lint command (if enabled)
   - If it fails, stop and fix before continuing
4. Only after ALL enabled loops pass, proceed to commit

This ensures errors are caught and fixed before moving on. Never batch multiple commands together where a failure could be masked.

### Sandbox Configuration

Some feedback loops need network access that the sandbox blocks:
- **Database connections**: Tests connecting to localhost:5432 or similar
- **Docker port forwarding**: Commands that need to reach containerized services
- **External APIs**: Integration tests hitting real endpoints

If you see errors like "Can't reach database server at localhost:5432", the project should set `sandbox: false` for that feedback loop in autopilot.json.

### Pre-existing Failures

**Ideally, projects should have green feedback loops before starting autopilot.** All typecheck, test, and lint commands should pass. This ensures autopilot can detect when your changes break something.

If a project has pre-existing failures that cannot be fixed immediately:

1. **Capture baseline at session start**: Run feedback loops and record error counts
2. **Configure in autopilot.json**: Add a `baseline` section with known failures
3. **Delta checking**: Autopilot should only fail on NEW errors beyond the baseline

Example baseline configuration:
```json
{
  "baseline": {
    "typecheck": { "errorCount": 5 },
    "tests": { "failingTests": ["test_legacy_*"] },
    "lint": { "errorCount": 12, "patterns": ["no-unused-vars"] }
  }
}
```

When running feedback loops with a baseline:
- If current errors <= baseline errors, consider it passing
- If current errors > baseline errors, a new error was introduced - fail
- Log which specific new errors appeared

## Token Frugality

Context accumulates within a session. To optimize token usage:

1. **Read notes first**: Always read the notes file before exploring. It contains current state and what was already done.
2. **Be concise**: Do not explain what you're about to do - just do it. Minimize commentary.
3. **Targeted reads**: Use line ranges instead of reading entire files when possible.
4. **Don't re-read**: If a file is summarized in notes, don't read it again unless modifying it.
5. **Structured notes**: Update the notes file with current state so the next session can resume efficiently.

### Notes File Format

The notes file (`*-notes.md`) should maintain a structured state section at the top.

**Initial template** - create this if the notes file does not exist:

```markdown
# [Task Name] Progress Notes

## Current State
- Last completed: none
- Working on: requirement 1
- Blockers: none

## Files Modified
(none yet)

## Session Log
- [date] Started task file
```

**Ongoing format** - update after each requirement:

```markdown
## Current State
- Last completed: requirement N
- Working on: requirement M
- Blockers: none | description

## Files Modified
- path/to/file.ts (brief description of changes)

## Session Log
- [timestamp] Completed requirement N: description
- [timestamp] Started requirement M
```

This format allows quick state reconstruction when starting a fresh session.

### Progress Tracking Per Requirement

For detailed tracking, maintain a `## Progress` section with structured data per requirement:

```markdown
## Progress

### Requirement 1: Description
- Started: 2026-01-09 10:30
- Completed: 2026-01-09 10:45
- Duration: 15 min
- Commits:
  - abc1234 Add failing test for feature X
  - def5678 Implement feature X
  - ghi9012 Refactor feature X implementation
- Files Changed:
  - src/feature.ts (new file)
  - tests/feature.test.ts (new file)

### Requirement 2: Description
- Started: 2026-01-09 10:46
- Status: in_progress
```

This structured format enables:
- Understanding time spent per requirement
- Tracking which commits belong to which requirement
- Quick identification of recently modified files
- Better context when resuming interrupted sessions

## Troubleshooting

### Tests can't connect to database (localhost:5432)

**Symptom:** Tests fail with "Can't reach database server at localhost:5432" even though Docker container is running and healthy.

**Cause:** Claude Code's sandbox blocks Docker port forwarding. The container works fine internally, but connections from the host to forwarded ports are blocked.

**Solution:**
1. Set `sandbox: false` in `autopilot.json` for the tests feedback loop:
   ```json
   "tests": {
     "enabled": true,
     "command": "npm test",
     "sandbox": false
   }
   ```
2. For ad-hoc test runs outside autopilot, use `dangerouslyDisableSandbox: true` in Bash tool calls.

**Don't waste time debugging Docker networking** - if you see this error, it's almost certainly the sandbox. Try disabling it first.

### Tests pass before implementation (Invalid Test)

**Symptom:** In TDD Red phase, the new test passes immediately without any implementation.

**Cause:** The test isn't actually testing new behavior - either the feature already exists, or the test has a bug.

**Solution:** Mark the requirement as `invalidTest: true` with `invalidTestReason` and skip to next requirement. Do NOT proceed with implementation.

---

## Phase 99999: Critical Guardrails

**These rules have the highest priority. Violating them causes immediate failure.**

### 99999. Feedback Loops Before Commits

Run ALL enabled feedback loops before every commit:
1. Typecheck (if enabled)
2. Tests (if enabled)
3. Lint (if enabled)

Run them sequentially. If ANY fails, stop and fix before proceeding.

### 999999. Never Commit on Failure

**NEVER commit if any feedback loop fails.**

Do not:
- Commit with failing tests
- Commit with type errors
- Commit with lint errors
- Batch commits hoping failures will be fixed later

Fix the failure first, verify all loops pass, then commit.

### 9999999. Search Before Implementing

**Don't assume something isn't implemented. Always search first.**

Before creating any new:
- Utility function → Search for existing utilities
- Component → Search for similar components
- Pattern → Search for existing patterns in the codebase

Use the codeAnalysis from the task file. Check existingFiles and patterns before writing new code.

### 99999999. No Placeholders or TODOs

**Implement fully or mark as stuck. No middle ground.**

Do not:
- Leave TODO comments in committed code
- Create placeholder functions or stub implementations
- Commit partial implementations with "will fix later"
- Add FIXME comments instead of fixing

If you cannot complete something:
1. Mark the requirement as `stuck: true`
2. Add a clear `blockedReason`
3. Log to notes file
4. Move to next requirement

### 999999999. Single Source of Truth

**No duplicate implementations. Extend existing code.**

Before creating new code:
1. Search for existing equivalent functionality
2. Check if you can extend an existing file/function
3. Look for utilities that already do what you need

If you find duplicates during refactor:
1. Consolidate to a single implementation
2. Update all usages
3. Log the consolidation to notes

Prefer:
- Extending existing code over creating parallel implementations
- Reusing utilities over reimplementing
- Following established patterns over inventing new ones

---

## Execution

**IMPORTANT: Avoid shell metacharacters in args.** The args string is passed through bash which interprets certain characters as shell syntax. To prevent errors:
- Do NOT use semicolons - use "then" or "and" instead
- Do NOT use parentheses - rephrase to avoid them
- Do NOT use colons in phrases like "HANDLING:" - just use plain words
- Use "and" instead of commas for lists
- Keep it as one plain text line without backticks or markdown

Parse the user's argument: $ARGUMENTS

Determine the mode, construct the appropriate prompt, and execute the skill.
