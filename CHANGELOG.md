# Changelog

All notable changes to Autopilot will be documented in this file.

## 2026-01-18

### Added
- **Command loop mode** - Run any slash command repeatedly with fresh sessions
  - Usage: `autopilot /my-command --max 5` or `/autopilot /my-command --max 5`
  - Runs the command N times, starting a fresh Claude session each iteration
  - Useful for repetitive tasks, batch processing, or running review commands multiple times
  - Default iterations configurable via `iterations.command` in autopilot.json (default: 10)
- **`--max N` flag** for run.sh command mode to specify iteration count
- **`iterations.command`** configuration in autopilot.json schema and template

### Changed
- **run.sh** now supports two modes: task file mode (existing) and command loop mode (new)
- **Argument parsing** for command mode uses explicit `--max N` to avoid ambiguity with command arguments

---

## 2026-01-15

### Added
- **Model selection** - `run.sh` now supports `--model` flag to choose Claude model (opus, sonnet, haiku, or full model name)
  - Example: `autopilot tasks.json --model sonnet` for faster, cheaper runs
  - Example: `autopilot tasks.json --model haiku --batch 5` for maximum speed
- **Debug logging** - Stop-hook includes DEBUG statements for troubleshooting completion detection
- **Sentinel stop file** - Autopilot writes `.autopilot/stop-signal` when all requirements complete, signaling `run.sh` to exit
- **Active session monitoring** - `run.sh` now runs Claude in background and actively monitors for completion
  - Checks task JSON every 2 seconds for progress
  - Detects batch completion and terminates for fresh context
  - Idle detection: restarts after 30s idle if progress was made (prevents stale context)
  - Timeout detection: terminates after 10 minutes with no progress (prevents stuck sessions)
- **Test fixtures** - Added `tests/fixtures/` with minimal autopilot.json and tasks-simple.json for development testing

### Fixed
- **Loop termination** - Stop-hook now sends SIGTERM to parent Claude process when complete, ensuring Claude actually exits (previously just returned "allow" which didn't force termination)
- **Batch completion detection** - `run.sh` now monitors task JSON for progress and terminates Claude when batch size is reached, avoiding context window exhaustion

---

## 2026-01-13

### Added
- **Quick Start guide** - New 5-minute getting started section with decision tree for choosing execution method
- **Expanded troubleshooting** - 15+ common issues with detailed solutions (was 4 items)
- **Monorepo examples** - `examples/autopilot-monorepo.json` and `examples/tasks-monorepo.json`
- **Mode: Metrics** - New command `/autopilot metrics` (alias for analyze with aggregation focus)
- **Dependency validation** - `run.sh` now checks for `jq` and `claude` CLI before running
- **JSON validation** - `run.sh` validates task file is valid JSON with requirements array
- **Progress visibility** - `run.sh` shows completed/stuck counts after each session

### Fixed
- **Iterations mismatch** - `init.md` now uses correct defaults (15/10/15/10) matching template and docs

### Improved
- **Error messages** - Configuration errors now include actionable fix instructions
- **Task file errors** - Better messages with common locations and how to generate

---

## 2026-01-13 (earlier)

### Added
- **Built-in loop mechanism** - Autopilot now includes its own stop-hook, eliminating the dependency on the external ralph-loop plugin
  - `hooks/stop-hook.sh` - Intercepts exit attempts, re-feeds prompts for iteration
  - `hooks/hooks.json` - Hook configuration template
  - State stored in `.autopilot/loop-state.md` with YAML frontmatter
- **`/autopilot cancel` command** - Cancel an active hook-based loop by removing the state file
  - Different from `/autopilot stop` which signals the run.sh wrapper
  - Graceful cancellation - current work completes before loop exits
- **Improved stop-hook features** (based on ralph-loop):
  - Reads transcript path from hook input JSON (not environment variable)
  - Uses Perl regex for robust `<promise>` tag extraction
  - Atomic iteration increment using temp file + move pattern
  - Supports unlimited iterations when max_iterations = 0
  - Better system message with promise guidance

### Changed
- **No external plugin required** - Autopilot is now fully self-contained
- **Installation** - `./install.sh` now installs hooks to `~/.claude/hooks/` and creates `~/.claude/hooks.json`
- **Loop state location** - Now uses `.autopilot/loop-state.md` (project-local) instead of `.claude/ralph-loop.local.md`

### Removed
- **Ralph Loop plugin dependency** - No longer requires `claude plugins:install claude-plugins-official`

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
