# Changelog

All notable changes to Autopilot will be documented in this file.

## 2026-01-11

### Added
- **Session Analytics** - Per-session analytics files track iterations, errors, timing, and waste patterns
  - Stored in `docs/tasks/analytics/` with timestamped filenames
  - Schema defined in `analytics.schema.json`
  - Example file: `examples/analytics-user-auth-session.json`
- **Thrashing Detection** - Automatically detects when the same error repeats consecutively
  - Configurable threshold via `analytics.thrashingThreshold` (default: 3)
  - Immediately marks task as stuck when thrashing detected
  - Logs pattern to analytics for post-session analysis
- **`/autopilot analyze` command** - Post-session analysis of analytics files
  - Calculates efficiency score (productive vs wasted iterations)
  - Identifies waste patterns (thrashing, environment issues, missing context)
  - Generates suggested AGENTS.md entries and autopilot.json changes
  - Supports `--last`, `--since Nd`, `--task <name>`, `--clear` flags
- **Analytics configuration** in `autopilot.json`:
  - `analytics.enabled` - Toggle analytics (default: true)
  - `analytics.directory` - Where to store files (default: `docs/tasks/analytics`)
  - `analytics.thrashingThreshold` - Consecutive errors before abort (default: 3)
  - `analytics.trackToolCalls` - Track tool usage per requirement
  - `analytics.trackFileAccess` - Track files read/written per requirement

### Changed
- **TDD mode** now logs errors, iterations, and timing to analytics file
- **Stuck handling** distinguishes between thrashing (same error) and regular stuck (different approaches failed)

## 2026-01-10

### Changed
- **AGENTS.md trimmed to 63 lines** - Removed Learnings section (progress tracker), condensed TDD Pitfalls. Keeps file purely operational per Ralph Playbook recommendation.
- **Language patterns documented** - Added Language Patterns section to CLAUDE.md with proven phrasings ("study" vs "read", "capture the why", etc.)
- **Subagent parallelization guidance** - Added section to CLAUDE.md explaining when to use parallel (exploration) vs sequential (execution) subagents

### Added
- **Codebase analysis in `/tasks`** - Before generating tasks, `/tasks` now explores the codebase to understand existing patterns, utilities, and implementations
- **Gap analysis** - Each requirement is categorized as `create`, `extend`, `modify`, or `already-done` based on what code already exists
- **`codeAnalysis` field** - Requirements now include rich context: `existingFiles`, `relatedTests`, `patterns`, and `targetFiles` (modify/create)
- **`--refresh` flag for `/tasks`** - Re-analyze incomplete requirements while preserving completed ones; useful for mid-implementation course correction
- **`tasks.schema.json`** - JSON Schema for task files, enabling validation and editor autocomplete
- **Phase-numbered structure** - Both `/tasks` and `autopilot.md` now use explicit phase numbering (Phase 0 for pre-flight, Phase 1+ for execution)
- **Critical guardrails section** - `autopilot.md` now has Phase 99999+ with escalating priority guardrails:
  - 99999: Feedback loops before commits
  - 999999: Never commit on failure
  - 9999999: Search before implementing
  - 99999999: No placeholders or TODOs
  - 999999999: Single source of truth
- **Guardrails in AGENTS.md** - Added Guardrails section with search-first, no-placeholders, and single-source-of-truth rules
- **Acceptance criteria for requirements** - New `acceptance` array defines specific, testable outcomes that become test cases in TDD Red phase

### Changed
- **TDD Red phase** - Now requires tests covering ALL acceptance criteria before proceeding to Green phase
- **Code-aware TDD descriptions** - Test and implementation descriptions now reference specific files, patterns, and utilities discovered during analysis
- **Example tasks file** - `examples/tasks-user-auth.json` updated with `codeAnalysis` examples showing the new structure
- **"Don't assume not implemented" guardrail** - Built into `/tasks` Phase 1 and `autopilot.md` guardrails, ensuring Claude searches before implementing

### Inspiration
- Gap analysis, phase numbering, and guardrail patterns adapted from [Ralph Playbook](https://github.com/ghuntley/ralph-playbook) by Geoffrey Huntley

## 2026-01-09

### Added
- **run.sh** - Token-frugal wrapper script that runs Claude in a loop with fresh context per requirement
- **--batch N flag** - Limit requirements completed per session for manual token management
- **Resume support** - `--start-from <id>` flag to resume from specific requirement
- **Rollback mechanism** - Git tags created before each requirement (`autopilot/req-{id}/start`), with `/autopilot rollback <id>` mode
- **Completion summary report** - Shows completed vs stuck requirements, commits made, and files modified when autopilot finishes
- **Progress tracking** - Structured YAML log in notes file tracking timing, commits, and files per requirement
- **Completion notifications** - Desktop notifications, webhooks, or ntfy.sh integration via `notifications` config
- **Test type support** - Requirements can specify `testType` (unit, integration, e2e) with different test commands
- **Issue tracker integration** - Link commits to GitHub Issues, auto-update issues on completion
- **Monorepo/workspace support** - Per-package feedback loops with `workspaces` config
- **Metrics tracking** - Optional collection of success rates, timing, and common stuck points
- **Auto-documentation** - Optional changelog/README updates after requirements complete
- **Example files** - `/examples/` directory with brainstorm, PRD, tasks, and notes examples
- **Sandbox config per feedback loop** - Control sandbox mode individually (for database/Docker tests)
- **Baseline failures** - Ignore pre-existing typecheck/test/lint failures via `baseline` config
- **Coverage targeting** - Prioritize critical paths, exclude generated files, focus on recent changes
- **Dependency ordering** - Requirements can specify `dependsOn` for parallel execution planning
- **TDD pitfalls documentation** - AGENTS.md section on test isolation and fixture conflicts
- **CLAUDE.md** - Context file for Claude Code with project overview, architecture, and key concepts

### Changed
- **Explicit TDD enforcement** - Tests must fail before implementation, flagged as invalid if they pass early
- **Smarter code-simplifier** - Explicitly tracks files modified per requirement, passes specific file list
- **Feedback loop joining** - Commands explicitly joined with `&&` for proper error handling
- **Iteration counts** - Updated documentation explaining expected iterations per requirement
- **Notes file bootstrap** - Gracefully handles missing notes file on first run, creates with template

### Fixed
- **Argument parsing** - Fixed Ralph Loop skill args with semicolons/parentheses being interpreted as shell commands
- **Pre-existing failures** - Baseline config allows autopilot to continue despite existing issues

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
