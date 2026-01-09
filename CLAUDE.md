# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Autopilot is a workflow toolkit for autonomous Test-Driven Development using Claude Code and the Ralph Loop plugin. The typical workflow:

1. `/prd feature-name` → Generate human-readable PRD via clarifying questions
2. `/tasks prd-file.md` → Convert PRD to machine-readable JSON task file
3. `/autopilot tasks.json` → Ralph Loop executes TDD cycles autonomously

## Architecture

**Commands** (`commands/*.md`) are symlinked to `~/.claude/commands/` and become slash commands:
- `prd.md` - Asks clarifying questions, outputs markdown PRD
- `tasks.md` - Parses PRD, outputs JSON with TDD tracking fields
- `autopilot.md` - Main entry point, dispatches to modes based on arguments
- `init.md` - Project configuration wizard, creates `autopilot.json`

**Supporting Files**:
- `autopilot.schema.json` - Validates `autopilot.json` structure
- `autopilot.template.json` - Starting point with null values for init to populate
- `AGENTS.md` - TDD guidelines, symlinked to `~/.claude/` for cross-project access

**Generated in User Projects**:
- `autopilot.json` - Feedback loops, iterations, project conventions
- `docs/tasks/prds/*.md` - Human-readable PRDs
- `docs/tasks/prds/*.json` - Machine-readable task files with TDD tracking
- `docs/tasks/prds/*-notes.md` - Progress logs for session continuity

## Key Concepts

**Ralph Loop**: The `ralph-loop:ralph-loop` skill runs Claude in a loop with a completion promise. Context accumulates between iterations. Autopilot passes structured prompts with `--completion-promise COMPLETE --max-iterations N`.

**Feedback Loops**: Commands run before each commit (typecheck, tests, lint). Configured in `autopilot.json`. Claude must not commit if any fail.

**TDD Phases**: Red (write failing test) → Green (minimal implementation) → Refactor (run code-simplifier). All three phases must complete before marking `passes: true`.

**Stuck Handling**: If the same task fails 3 consecutive iterations, mark it `stuck: true` with a `blockedReason` and move to the next task.

**Token Frugality**: Context accumulates within Ralph Loop sessions. Default iterations are low (10-15). Always read `*-notes.md` first. Use targeted file reads. Restart sessions frequently.

**Code Simplifier**: The `code-simplifier` agent (via Task tool) runs during TDD refactor phase to improve clarity while preserving functionality.

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

## Development

This repo has no build system or tests - it's pure markdown documentation. Changes are immediately available after `git pull`.

**Installation**: `./install.sh` creates symlinks to `~/.claude/commands/` and `~/.claude/AGENTS.md`

**Uninstall**: `rm ~/.claude/commands/{prd,tasks,autopilot,init}.md ~/.claude/AGENTS.md`

## JSON Schema

`autopilot.schema.json` validates `autopilot.json`. Key required fields:
- `project.type` - Language/framework (nodejs, python, go, etc.)
- `feedbackLoops.tests.command` - Test command (unless `enabled: false`)
- `feedbackLoops.lint.command` - Lint command (unless `enabled: false`)
- `iterations.*` - Max iterations per mode (defaults: tasks=15, tests=10, lint=15, entropy=10)
