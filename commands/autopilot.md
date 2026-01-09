# Autopilot

Start an autonomous work session with progress tracking and learnings.

## Usage

```
/autopilot <file.json> [max-iterations]    # TDD task completion mode (default)
/autopilot tests [target%] [max-iterations] # Test coverage mode
/autopilot lint [max-iterations]            # Linting mode
/autopilot entropy [max-iterations]         # Code cleanup mode
```

Default max-iterations is 20 for all modes. Pass a number to override.

## Argument Parsing

Parse `$ARGUMENTS` to extract:
1. **Mode** - Determined by first argument (file path, `tests`, `lint`, or `entropy`)
2. **Max iterations** - Optional trailing number (default: 20)
3. **Mode-specific params** - Target percentage for tests mode, file path for TDD mode

Examples:
- `/autopilot tasks.json` → TDD mode, 20 iterations
- `/autopilot tasks.json 30` → TDD mode, 30 iterations
- `/autopilot tests 80` → Test mode, 80% target, 20 iterations
- `/autopilot tests 80 15` → Test mode, 80% target, 15 iterations
- `/autopilot lint 10` → Lint mode, 10 iterations

## Mode Detection

Based on the argument ($ARGUMENTS), determine the mode:

1. **If argument ends with `.json` or `.md`** → TDD task completion mode
2. **If argument starts with `tests`** → Test coverage mode
3. **If argument starts with `lint`** → Linting mode
4. **If argument starts with `entropy`** → Entropy/cleanup mode

## Mode: TDD Task Completion (default)

For file paths (`.json` or `.md` files). Uses Test-Driven Development.

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `Complete requirements in TASKFILE using TDD. For each requirement: 1) Write failing test first, run tests to confirm it fails, commit test. 2) Write minimal implementation to pass the test, run tests to confirm it passes, commit implementation. 3) Run code-simplifier agent on modified files, then run typecheck tests lint to verify still green, commit refactor. Mark tdd.test.passes, tdd.implement.passes, tdd.refactor.passes as you complete each phase. Mark requirement passes true only when all three phases done. Before committing, run typecheck, tests, lint. Do NOT commit if any fail. STUCK HANDLING: If you fail the same task 3 iterations in a row, add stuck:true and blockedReason to the requirement, log the blocker to notes file, skip to next requirement. After each requirement, append progress to TASKFILE-notes.md. Log learnings to AGENTS.md. Output COMPLETE when all requirements pass or all remaining are stuck. --completion-promise COMPLETE --max-iterations MAXITER`

Replace TASKFILE with the provided file path. Replace MAXITER with the provided number (default: 20).

## Mode: Test Coverage

For `tests` or `tests <target%>` arguments.

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `Run test coverage report. Find uncovered lines. Write tests for the most critical uncovered code paths. Run coverage again to verify improvement. Target: TARGET% coverage minimum. STUCK HANDLING: If you cannot increase coverage after 3 consecutive iterations, log the blocker to notes file and output COMPLETE with current coverage. Append progress to docs/tasks/test-coverage-notes.md. Log learnings to AGENTS.md. Commit after each test file passes. Output COMPLETE when target coverage reached or stuck. --completion-promise COMPLETE --max-iterations MAXITER`

Replace TARGET with the provided percentage (default: 80). Replace MAXITER with the provided number (default: 20).

## Mode: Linting

For `lint` argument.

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `Run linter. Fix ONE linting error at a time. Run lint again to verify the fix. Do not batch fixes. STUCK HANDLING: If you cannot fix a specific lint error after 3 attempts, log it to notes file with the error details and skip to next error. Append progress to docs/tasks/lint-fixes-notes.md. Log learnings to AGENTS.md. Commit after each fix passes lint. Output COMPLETE when no lint errors remain or only stuck errors remain. --completion-promise COMPLETE --max-iterations MAXITER`

Replace MAXITER with the provided number (default: 20).

## Mode: Entropy

For `entropy` argument.

Use the Skill tool with:
- skill: `ralph-loop:ralph-loop`
- args: `Run code-simplifier agent on recently modified files. Then scan for code smells: unused exports, dead code, inconsistent patterns, duplicate code, overly complex functions. Fix ONE issue at a time. Run typecheck, tests, lint after each fix. Do NOT commit if any fail. STUCK HANDLING: If you cannot fix an issue after 3 attempts, log it to notes file and move on. Append what you changed to docs/tasks/entropy-cleanup-notes.md. Log learnings to AGENTS.md. Commit after each fix passes all checks. Output COMPLETE when no obvious code smells remain or only stuck issues remain. --completion-promise COMPLETE --max-iterations MAXITER`

Replace MAXITER with the provided number (default: 20).

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

- Before committing, run feedback loops: typecheck, tests, lint
- Do NOT commit if any feedback loop fails - fix first
- Log mistakes or learnings to AGENTS.md
- Keep changes small and focused (one logical change per commit)
- After 3 failed attempts on same issue, mark stuck and move on

## Execution

Do not include backticks, markdown formatting, or multi-line content in the args. Keep it as one plain text line.

Parse the user's argument: $ARGUMENTS

Determine the mode, construct the appropriate prompt, and execute the skill.
