# Changelog

All notable changes to Autopilot will be documented in this file.

## 2026-01-09

### Added
- **CLAUDE.md** - Context file for Claude Code with project overview, architecture, and key concepts

## 2025-01-09

### Added
- **Token Frugality Mode** - All prompts now include instructions to minimize token usage
  - Read notes file first to understand current state
  - Be concise - do not explain, just act
  - Use targeted file reads (line ranges instead of full files)
  - Don't re-read files already summarized in notes
- **Structured Notes Format** - Notes files maintain a `Current State` section for quick state reconstruction
- **Token Frugality section** in README explaining the optimization strategies

### Changed
- **Lower default iterations** for all modes to encourage frequent session restarts:
  - tasks: 50 → 15
  - tests: 30 → 10
  - lint: 50 → 15
  - entropy: 30 → 10
- Updated autopilot.json schema with new defaults
- Updated autopilot.template.json with new defaults
- All mode prompts rewritten to be more concise

### Fixed
- Explicitly skip completed requirements (`passes: true`) in TDD mode

## 2025-01-08

### Added
- Initial release
- `/prd` command - Create human-readable PRDs with clarifying questions
- `/tasks` command - Convert PRDs to machine-readable JSON with TDD phases
- `/autopilot` command with four modes:
  - TDD task completion (default)
  - Test coverage improvement
  - Lint error fixing
  - Entropy/code cleanup
- `/autopilot init` command for project configuration
- TDD enforcement (Red → Green → Refactor cycle)
- Code-simplifier integration during refactor phase
- Stuck handling after 3 failed iterations
- Feedback loops (typecheck, tests, lint) before commits
- Progress tracking via notes files
- Learnings logged to AGENTS.md
- Symlink-based installation for easy updates
