# Autopilot

Start an autonomous work session with progress tracking and learnings.

## Usage

```
/autopilot init                             # Initialize project configuration
/autopilot <file.json> [max-iterations]    # TDD task completion mode (default)
/autopilot tests [target%] [max-iterations] # Test coverage mode
/autopilot lint [max-iterations]            # Linting mode
/autopilot entropy [max-iterations]         # Code cleanup mode
```

Default max-iterations are configured in `autopilot.json` (tasks: 15, tests: 10, lint: 15, entropy: 10). Pass a number to override. Lower defaults optimize for token frugality - restart sessions frequently for fresh context.

## Pre-flight: Configuration Check

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
```

Then stop execution. Do not proceed without configuration.

### If `autopilot.json` exists but has null required values:

Check these required fields:
- `project.type` - must not be null
- `feedbackLoops.tests.command` - must not be null (unless `enabled: false`)
- `feedbackLoops.lint.command` - must not be null (unless `enabled: false`)

If any required fields are null, tell the user:
```
Autopilot configuration is incomplete. Missing: <list missing fields>

Run /autopilot init to complete the setup, or manually edit autopilot.json.
```

Then stop execution.

### If `autopilot.json` is valid:

Read the configuration and use:
- `iterations.tasks`, `iterations.tests`, `iterations.lint`, `iterations.entropy` as default max iterations
- `feedbackLoops.typecheck.command`, `feedbackLoops.tests.command`, `feedbackLoops.lint.command` for pre-commit checks
- `project.conventions.testFilePattern` and `project.conventions.testDirectory` for test locations

Proceed to argument parsing and mode execution.

## Argument Parsing

Parse `$ARGUMENTS` to extract:
1. **Mode** - Determined by first argument (`init`, file path, `tests`, `lint`, or `entropy`)
2. **Max iterations** - Optional trailing number (defaults from autopilot.json)
3. **Mode-specific params** - Target percentage for tests mode, file path for TDD mode

Examples:
- `/autopilot init` → Run initialization wizard
- `/autopilot init --force` → Run initialization with auto-detected values
- `/autopilot tasks.json` → TDD mode, iterations from config (default: 50)
- `/autopilot tasks.json 30` → TDD mode, 30 iterations
- `/autopilot tests 80` → Test mode, 80% target, iterations from config (default: 30)
- `/autopilot tests 80 15` → Test mode, 80% target, 15 iterations
- `/autopilot lint 10` → Lint mode, 10 iterations

## Mode Detection

Based on the argument ($ARGUMENTS), determine the mode:

1. **If argument is `init`** → Run `/autopilot init` command (invoke the init.md command)
2. **If argument ends with `.json` or `.md`** → TDD task completion mode
3. **If argument starts with `tests`** → Test coverage mode
4. **If argument starts with `lint`** → Linting mode
5. **If argument starts with `entropy`** → Entropy/cleanup mode

## Mode: Init

For `init` argument, invoke the `/autopilot init` command to run the initialization wizard.

Pass any additional arguments (like `--force`, `--skip-validation`) to the init command.

## Mode: TDD Task Completion (default)

For file paths (`.json` or `.md` files). Uses Test-Driven Development.

Read `autopilot.json` to get:
- `TYPECHECK_CMD` from `feedbackLoops.typecheck.command` (if enabled)
- `TEST_CMD` from `feedbackLoops.tests.command`
- `LINT_CMD` from `feedbackLoops.lint.command`
- `MAXITER` default from `iterations.tasks` (usually 15)

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `TOKEN FRUGAL MODE: Read TASKFILE-notes.md first to understand current state. Be concise - do not explain, just act. Use targeted file reads. Complete requirements in TASKFILE using TDD. Skip any requirement with passes:true. For the next incomplete requirement: 1) Write failing test, run TEST_CMD to confirm fail, commit. 2) Write minimal implementation, run TEST_CMD to confirm pass, commit. 3) Run code-simplifier on modified files, run TYPECHECK_CMD TEST_CMD LINT_CMD to verify green, commit. Mark tdd.test.passes, tdd.implement.passes, tdd.refactor.passes as you complete each phase. Mark requirement passes true only when all three phases done. Before committing, run TYPECHECK_CMD TEST_CMD LINT_CMD. Do NOT commit if any fail. STUCK HANDLING: If same task fails 3 iterations, add stuck:true and blockedReason, log blocker to notes, skip to next. After each requirement, update TASKFILE-notes.md with Current State section showing last completed, working on, and blockers. Log learnings to AGENTS.md. Output COMPLETE when all requirements pass or all remaining are stuck. --completion-promise COMPLETE --max-iterations MAXITER`

Replace:
- TASKFILE with the provided file path
- MAXITER with the provided number or default from `iterations.tasks`
- TYPECHECK_CMD, TEST_CMD, LINT_CMD with commands from autopilot.json (omit if disabled)

## Mode: Test Coverage

For `tests` or `tests <target%>` arguments.

Read `autopilot.json` to get:
- `TEST_CMD` from `feedbackLoops.tests.command`
- `MAXITER` default from `iterations.tests` (usually 10)

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `TOKEN FRUGAL MODE: Read docs/tasks/test-coverage-notes.md first. Be concise - do not explain, just act. Use targeted file reads. Run coverage report. Find uncovered lines. Write tests for critical uncovered paths. Run TEST_CMD to verify pass. Run coverage to verify improvement. Target: TARGET% minimum. STUCK HANDLING: If no coverage increase after 3 iterations, log blocker to notes, output COMPLETE with current coverage. Update notes with Current State section. Log learnings to AGENTS.md. Commit after each test passes. Output COMPLETE when target reached or stuck. --completion-promise COMPLETE --max-iterations MAXITER`

Replace:
- TARGET with the provided percentage (default: 80)
- MAXITER with the provided number or default from `iterations.tests`
- TEST_CMD with command from autopilot.json

## Mode: Linting

For `lint` argument.

Read `autopilot.json` to get:
- `LINT_CMD` from `feedbackLoops.lint.command`
- `MAXITER` default from `iterations.lint` (usually 15)

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `TOKEN FRUGAL MODE: Read docs/tasks/lint-fixes-notes.md first. Be concise - do not explain, just act. Use targeted file reads. Run LINT_CMD. Fix ONE error at a time. Run LINT_CMD to verify fix. Do not batch fixes. STUCK HANDLING: If same error fails 3 attempts, log to notes with details, skip to next. Update notes with Current State section. Log learnings to AGENTS.md. Commit after each fix passes. Output COMPLETE when no errors remain or only stuck errors. --completion-promise COMPLETE --max-iterations MAXITER`

Replace:
- MAXITER with the provided number or default from `iterations.lint`
- LINT_CMD with command from autopilot.json

## Mode: Entropy

For `entropy` argument.

Read `autopilot.json` to get:
- `TYPECHECK_CMD` from `feedbackLoops.typecheck.command` (if enabled)
- `TEST_CMD` from `feedbackLoops.tests.command`
- `LINT_CMD` from `feedbackLoops.lint.command`
- `MAXITER` default from `iterations.entropy` (usually 10)

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `TOKEN FRUGAL MODE: Read docs/tasks/entropy-cleanup-notes.md first. Be concise - do not explain, just act. Use targeted file reads. Run code-simplifier on recent files. Scan for code smells: unused exports, dead code, inconsistent patterns, duplicates, complex functions. Fix ONE issue at a time. Run TYPECHECK_CMD TEST_CMD LINT_CMD after each fix. Do NOT commit if any fail. STUCK HANDLING: If same issue fails 3 attempts, log to notes, move on. Update notes with Current State section. Log learnings to AGENTS.md. Commit after each fix passes. Output COMPLETE when no smells remain or only stuck issues. --completion-promise COMPLETE --max-iterations MAXITER`

Replace:
- MAXITER with the provided number or default from `iterations.entropy`
- TYPECHECK_CMD, TEST_CMD, LINT_CMD with commands from autopilot.json (omit if disabled)

## Stuck Handling

All modes include stuck handling to prevent infinite loops on intractable problems:

1. **Detection**: Same task/error failing for 3 consecutive iterations
2. **Action**: Log the blocker with details to the notes file
3. **Recovery**: Mark as stuck, skip to next task, continue working
4. **Completion**: Output COMPLETE when done or only stuck items remain

This ensures autopilot makes progress even when some tasks are blocked.

## Code Simplifier

The `code-simplifier` agent simplifies code for clarity and maintainability while preserving functionality. Use it via the Task tool with `subagent_type: code-simplifier`.

When to run:
- **TDD Refactor phase**: After implementation passes tests, before committing refactor
- **Entropy mode**: At the start of each iteration on recently modified files

## TDD Rules (Task Completion Mode)

1. **Red**: Write test first, verify it FAILS before proceeding
2. **Green**: Write minimal code to make test pass
3. **Refactor**: Run code-simplifier, then verify tests still green
4. **Never skip**: All three phases required for each requirement
5. **One at a time**: Complete full TDD cycle before next requirement

## Common Behaviors (All Modes)

- Read feedback loop commands from `autopilot.json`
- Before committing, run enabled feedback loops: typecheck, tests, lint
- Do NOT commit if any feedback loop fails - fix first
- Skip disabled feedback loops (where `enabled: false`)
- Log mistakes or learnings to AGENTS.md
- Keep changes small and focused (one logical change per commit)
- After 3 failed attempts on same issue, mark stuck and move on

## Token Frugality

Context accumulates within a session. To optimize token usage:

1. **Read notes first**: Always read the notes file before exploring. It contains current state and what was already done.
2. **Be concise**: Do not explain what you're about to do - just do it. Minimize commentary.
3. **Targeted reads**: Use line ranges instead of reading entire files when possible.
4. **Don't re-read**: If a file is summarized in notes, don't read it again unless modifying it.
5. **Structured notes**: Update the notes file with current state so the next session can resume efficiently.

### Notes File Format

The notes file (`*-notes.md`) should maintain a structured state section at the top:

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

## Execution

Do not include backticks, markdown formatting, or multi-line content in the args. Keep it as one plain text line.

Parse the user's argument: $ARGUMENTS

Determine the mode, construct the appropriate prompt, and execute the skill.
