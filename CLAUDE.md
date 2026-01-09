# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Autopilot is a workflow toolkit for autonomous Test-Driven Development using Claude Code and the Ralph Loop plugin. It provides custom slash commands (`/prd`, `/tasks`, `/autopilot`) that enable users to write a PRD, convert it to machine-readable tasks, then let Claude implement everything using TDD while they're away.

## Architecture

```
autopilot/
├── commands/           # Slash command definitions (symlinked to ~/.claude/commands/)
│   ├── prd.md         # /prd - Generate PRD via clarifying questions
│   ├── tasks.md       # /tasks - Convert PRD to JSON task file
│   ├── autopilot.md   # /autopilot - Main entry point for all modes
│   └── init.md        # /autopilot init - Project configuration wizard
├── autopilot.schema.json   # JSON Schema for autopilot.json validation
├── autopilot.template.json # Template for new autopilot.json files
├── AGENTS.md          # TDD guidelines and learnings (symlinked to ~/.claude/)
└── install.sh         # Creates symlinks to ~/.claude/
```

The workflow produces files in user projects:
- `autopilot.json` - Project configuration (feedback loops, iterations, conventions)
- `docs/tasks/prds/*.md` - Human-readable PRDs
- `docs/tasks/prds/*.json` - Machine-readable task files
- `docs/tasks/prds/*-notes.md` - Progress logs for each task file

## Key Concepts

**Feedback Loops**: Commands run before each commit (typecheck, tests, lint). Configured in `autopilot.json`. Claude must not commit if any fail.

**TDD Phases**: Each requirement goes through Red (failing test) → Green (minimal implementation) → Refactor (cleanup). All three phases must complete before marking `passes: true`.

**Stuck Handling**: If the same task fails 3 consecutive iterations, mark it `stuck: true` with a `blockedReason` and move to the next task.

**Token Frugality**: Ralph Loop accumulates context. Default iterations are low (10-15). Always read `*-notes.md` first to understand state. Keep sessions short and restart frequently.

## Autopilot Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| init | `/autopilot init` | Detect project config, create `autopilot.json` |
| tasks | `/autopilot file.json` | TDD task completion from JSON file |
| tests | `/autopilot tests [%]` | Increase test coverage to target |
| lint | `/autopilot lint` | Fix lint errors one by one |
| entropy | `/autopilot entropy` | Clean up code smells and dead code |

## Development

This repo has no build system or tests - it's pure markdown documentation that gets symlinked to `~/.claude/`. Changes are immediately available after `git pull`.

**Installation**: Run `./install.sh` to create symlinks from this repo to `~/.claude/commands/` and `~/.claude/AGENTS.md`.

**Uninstall**: Remove the symlinks manually:
```bash
rm ~/.claude/commands/{prd,tasks,autopilot,init}.md ~/.claude/AGENTS.md
```

## JSON Schema

`autopilot.schema.json` validates `autopilot.json` files. Key required fields:
- `project.type` - Language/framework (nodejs, python, go, etc.)
- `feedbackLoops.tests.command` - Test command (unless disabled)
- `feedbackLoops.lint.command` - Lint command (unless disabled)
- `iterations.*` - Max iterations per mode (defaults: tasks=15, tests=10, lint=15, entropy=10)
