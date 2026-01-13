# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Autopilot is a workflow toolkit for autonomous Test-Driven Development using Claude Code. It includes a built-in loop mechanism (stop-hook) that enables iterative execution without external dependencies. The typical workflow:

1. `/prd feature-name` → Generate human-readable PRD via clarifying questions
2. `/tasks prd-file.md` → Convert PRD to machine-readable JSON task file
3. `/autopilot tasks.json` → Execute TDD cycles autonomously via built-in loop

## Architecture

**Commands** (`commands/*.md`) are symlinked to `~/.claude/commands/` and become slash commands:
- `prd.md` - Asks clarifying questions, outputs markdown PRD
- `tasks.md` - Parses PRD, outputs JSON with TDD tracking fields
- `autopilot.md` - Main entry point, dispatches to modes based on arguments
- `init.md` - Project configuration wizard, creates `autopilot.json`
- `analyze.md` - Post-session analytics analysis, generates improvement suggestions

**Hooks** (`hooks/*.sh`) provide the loop mechanism:
- `stop-hook.sh` - Intercepts exit attempts, re-feeds the prompt for iteration
- Installed to `~/.claude/hooks/autopilot-stop-hook.sh`

**Supporting Files**:
- `autopilot.schema.json` - Validates `autopilot.json` structure
- `autopilot.template.json` - Starting point with null values for init to populate
- `AGENTS.md` - TDD guidelines, symlinked to `~/.claude/` for cross-project access
- `run.sh` - Token-frugal bash wrapper for fresh sessions per requirement

**Generated in User Projects**:
- `autopilot.json` - Feedback loops, iterations, project conventions
- `docs/tasks/prds/*.md` - Human-readable PRDs
- `docs/tasks/prds/*.json` - Machine-readable task files with TDD tracking
- `docs/tasks/prds/*-notes.md` - Progress logs for session continuity

## Key Concepts

**Loop Mechanism**: The built-in stop-hook (`hooks/stop-hook.sh`) intercepts Claude's exit attempts and re-feeds the prompt for iteration. State is stored in `.autopilot/loop-state.md` with iteration count, max iterations, and completion promise. When Claude outputs COMPLETE or reaches max iterations, the loop exits.

**Feedback Loops**: Commands run before each commit (typecheck, tests, lint). Configured in `autopilot.json`. Claude must not commit if any fail.

**TDD Phases**: Red (write failing test) → Green (minimal implementation) → Refactor (run code-simplifier). All three phases must complete before marking `passes: true`.

**Stuck Handling**: If the same task fails 3 consecutive iterations, mark it `stuck: true` with a `blockedReason` and move to the next task.

**Token Frugality**: Context accumulates within loop sessions. Default iterations are low (10-15). Always read `*-notes.md` first. Use targeted file reads. Use `run.sh` for fresh sessions per requirement.

**Code Simplifier**: The `code-simplifier` agent (via Task tool) runs during TDD refactor phase to improve clarity while preserving functionality.

**Analytics**: Per-session analytics files track iterations, errors, and waste patterns. Stored in `docs/tasks/analytics/`. Use `/autopilot analyze` to generate improvement suggestions.

**Thrashing Detection**: If the same error appears N times consecutively (default: 3), the task is immediately marked stuck. This prevents wasting tokens on unsolvable problems.

## Analytics System

Analytics help identify token waste and improvement opportunities across autopilot sessions.

**Files**:
- `analytics.schema.json` - Schema for session analytics files
- `commands/analyze.md` - Post-session analysis command
- `docs/tasks/analytics/*.json` - Per-session analytics (in user projects)

**Configuration** in `autopilot.json`:
```json
{
  "analytics": {
    "enabled": true,
    "directory": "docs/tasks/analytics",
    "thrashingThreshold": 3
  }
}
```

**Workflow**:
1. Autopilot creates analytics file at session start
2. Logs errors, iterations, and timing per requirement
3. Detects thrashing (same error N times) and aborts early
4. After session, run `/autopilot analyze` for suggestions
5. Apply relevant learnings to AGENTS.md or autopilot.json
6. Delete analytics files after review

**Waste Patterns Detected**:
- Thrashing (same error repeated)
- Environment issues (sandbox, connections)
- Missing context (duplicate implementations)
- Invalid tests (pass before implementation)

## Notes File Format

Notes files maintain state between sessions:

```markdown
## Current State
- Last completed: requirement N
- Working on: requirement M
- Blockers: none | description

## Files Modified
- path/to/file.ts (brief description)

## Session Log
- [timestamp] Completed requirement N: description
```

## Autopilot Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| init | `/autopilot init` | Detect project config, create `autopilot.json` |
| tasks | `/autopilot file.json` | TDD task completion from JSON file |
| tests | `/autopilot tests [%]` | Increase test coverage to target |
| lint | `/autopilot lint` | Fix lint errors one by one |
| entropy | `/autopilot entropy` | Clean up code smells and dead code |
| analyze | `/autopilot analyze` | Generate suggestions from session analytics |

## Development

This repo has no build system or tests - it's pure markdown documentation. Changes are immediately available after `git pull`.

**Installation**: `./install.sh` creates symlinks to `~/.claude/commands/`, `~/.claude/hooks/`, and `~/.claude/AGENTS.md`

**Uninstall**: `rm ~/.claude/commands/{prd,tasks,autopilot,init,analyze}.md ~/.claude/AGENTS.md ~/.claude/hooks/autopilot-stop-hook.sh`

## Examples

The `examples/` directory contains reference files:
- `brainstorm.md` - Initial feature brainstorm before PRD
- `prd-user-auth.md` - Example PRD document
- `tasks-user-auth.json` - Example task file with TDD tracking
- `notes-user-auth.md` - Example progress notes file
- `analytics-user-auth-session.json` - Example session analytics with thrashing detection

## Language Patterns

Certain phrasings improve Claude's behavior. Use these patterns in prompts:

| Pattern | Instead of | Why |
|---------|------------|-----|
| "study" | "read" | Implies deeper understanding, not just scanning |
| "using parallel subagents" | (nothing) | Triggers parallelization for exploration |
| "don't assume not implemented" | (nothing) | Triggers search-before-implement behavior |
| "capture the why" | (nothing) | Encourages documenting rationale in commits |

## Subagent Parallelization

Use parallel subagents for exploration, sequential for execution.

| Task Type | Strategy | Why |
|-----------|----------|-----|
| File reading | Parallel | No side effects, can read many files at once |
| Grep/search | Parallel | Independent searches, faster exploration |
| Codebase analysis | Parallel | Study multiple areas simultaneously |
| Tests | Sequential | Need to see results before deciding next step |
| Builds | Sequential | Must complete before validating |
| Commits | Sequential | Require backpressure and verification |

**Rule of thumb:** Reading/exploring → parallel subagents. Writing/executing → sequential with feedback.

## JSON Schema

`autopilot.schema.json` validates `autopilot.json`. Key required fields:
- `project.type` - Language/framework (nodejs, python, go, etc.)
- `feedbackLoops.tests.command` - Test command (unless `enabled: false`)
- `feedbackLoops.lint.command` - Lint command (unless `enabled: false`)
- `iterations.*` - Max iterations per mode (defaults: tasks=15, tests=10, lint=15, entropy=10)
