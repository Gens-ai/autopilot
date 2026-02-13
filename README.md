# Autopilot: Autonomous TDD Development with Claude Code

A workflow for autonomous, test-driven development using Claude Code. Write a PRD, convert it to tasks, then let Claude implement everything using TDD while you sleep.

Inspired by the [Ralph Wiggum technique](https://ghuntley.com/ralph/), autopilot includes its own built-in loop mechanism - no external plugins required.

[Watch the intro video](https://www.loom.com/share/741f5db667c4485c9571dc6ec1a5a994)

## Credits

This workflow gratefully builds on contributions from the community:

- [Ralph Wiggum](https://ghuntley.com/ralph/) by [Geoffrey Huntley](https://ghuntley.com/author/ghuntley/) — The autonomous loop approach
- [ai-dev-tasks](https://github.com/snarktank/ai-dev-tasks) by [Ryan Carson](https://www.youtube.com/watch?v=RpvQH0r0ecM) — PRD and task generation prompts
- [Matt Pocock](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) — Ralph workflow tips
- [ralph-playbook](https://github.com/ClaytonFarr/ralph-playbook) by [Clayton Farr](https://github.com/ClaytonFarr) — Additional workflow tips

## Quick Start (5 minutes)

**New project? Follow this flow:**

```
1. Install autopilot          → ./install.sh (one-time)
2. Initialize your project    → /autopilot init
3. Write a PRD                 → /prd "add user login feature"
4. Generate tasks              → /tasks docs/tasks/prds/user-login.md
5. Enable sandbox              → /sandbox
6. Run autopilot               → autopilot docs/tasks/prds/user-login.json
```

**Already have a task file?**

```bash
# Recommended: Fresh context per requirement (for 5+ requirements)
autopilot tasks.json

# Alternative: Single session (for 1-4 requirements)
/autopilot tasks.json
```

**Decision tree:**

```
                    How many requirements?
                           │
              ┌────────────┴────────────┐
              │                         │
           1-4                        5+
              │                         │
              ▼                         ▼
      /autopilot tasks.json    autopilot tasks.json
      (single session,         (fresh context,
       shared context)          token efficient)
```

**Need help?** See [Troubleshooting](#troubleshooting) or run `/autopilot --help`.

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with an active subscription
- [jq](https://jqlang.github.io/jq/) - JSON processor (used by `autopilot` (bash) to check task status)
- A project with feedback loops:
  - **Tests** - Any test runner (Jest, Vitest, pytest, go test, RSpec, etc.)
  - **Linter** - Any linter (ESLint, Ruff, golangci-lint, RuboCop, etc.)
  - **Type checker** (optional) - TypeScript, mypy, etc.

## Installation

### 1. Clone this repo

```bash
git clone https://github.com/Gens-ai/autopilot.git
cd autopilot
```

### 2. Run the install script

```bash
./install.sh
```

This creates symlinks:
- `~/.claude/commands/prd.md` → repo (slash command)
- `~/.claude/commands/tasks.md` → repo (slash command)
- `~/.claude/commands/autopilot.md` → repo (slash command)
- `~/.claude/AGENTS.md` → repo
- `~/.claude/hooks/autopilot-stop-hook.sh` → repo (loop mechanism)
- `~/.local/bin/autopilot` → repo/`run.sh` (terminal command)
- `~/.local/bin/autopilot-cleanup` → repo/`cleanup.sh` (process cleanup)

The install script also creates `~/.claude/hooks.json` with the stop-hook configuration if it doesn't exist.

Updates to the repo are automatically available (just `git pull`).

**Note:** Ensure `~/.local/bin` is in your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.bashrc or ~/.zshrc
```

### 3. Restart Claude Code

Start a new Claude Code session for the commands to become available.

### 4. Verify installation

```bash
# These commands should now be available:
/prd
/tasks
/autopilot
```

## Workflow

```
/autopilot init          → Initialize project configuration (one-time setup)
/prd feature-name        → Human-readable PRD (you review)
/tasks prd-file.md       → Machine-readable JSON (for autopilot)
/sandbox                 → Enable sandbox mode (highly adivsed for safer autonomy)
/autopilot tasks.json    → Autonomous TDD execution
```

### Pro Tip: Brainstorm First

For best results, start by brainstorming your feature in a markdown file before running `/prd`. Jot down your ideas, requirements, and any technical considerations. Then feed that file to the `/prd` command - Claude will ask clarifying questions to refine your rough ideas into a well-structured implementation plan.

```bash
# Brainstorm your feature
docs/plans/my-feature-brainstorm.md

# Then run /prd with your notes
/prd @docs/plans/my-feature-brainstorm.md
```

The better your initial thinking, the better the output.

## Two Ways to Run Autopilot

There are two ways to execute autopilot, with different tradeoffs:

| Method | Context | Best For |
|--------|---------|----------|
| `autopilot` (bash) | Fresh each requirement | Large task files, overnight runs |
| `/autopilot` | Accumulates in session | Small tasks, interactive use |

### Option 1: `autopilot` bash command (Recommended)

The **wrapper script** runs Claude in a loop, starting a **fresh session for each requirement**. This clears context between requirements, keeping token usage efficient.

```bash
autopilot docs/tasks/prds/feature.json
```

**How it works:**
1. Checks the task JSON for incomplete requirements
2. Invokes `claude --allowedTools ... "/autopilot <file> --batch 1"`
3. Claude completes one requirement, then exits
4. Script checks for remaining requirements
5. If more remain, starts a new Claude session (fresh context)
6. Repeats until all requirements are complete or stuck

**First-time setup per project:** The first time you run `autopilot` in a new project directory, Claude Code will show a one-time workspace trust prompt ("Is this a project you created or one you trust?"). Accept it once — subsequent sessions in that directory won't prompt again.

**Why fresh context matters:**
- Claude Code's Ralph Loop accumulates context within a session
- After 5-10 requirements, context can exceed limits or degrade quality
- Fresh sessions mean Claude starts clean each time
- State is preserved in the task JSON and notes file, not in memory

**Options:**
```bash
autopilot tasks.json              # 1 requirement per session (most frugal)
autopilot tasks.json --batch 3    # 3 requirements per session (faster)
autopilot tasks.json --model sonnet  # Use Sonnet instead of Opus (faster, cheaper)
autopilot tasks.json --delay 5    # 5 second pause between sessions
autopilot tasks.json --dry-run    # Preview without executing
autopilot tasks.json --cleanup    # Kill stale processes before starting
autopilot /my-command --max 5     # Run slash command 5 times (command loop mode)
```

**Model options:** `opus` (default), `sonnet`, `haiku`, or full model names like `claude-sonnet-4-5-20250929`

**When to use:**
- Task files with 5+ requirements
- Running overnight or unattended
- When you want maximum token efficiency
- Large codebases where context matters

**Stopping autopilot:**

Autopilot stops automatically when all requirements are complete—it writes `.autopilot/stop-signal` which tells `run.sh` to exit.

To stop manually, run `/autopilot stop` from another Claude Code session (sends `SIGUSR1` to the PID in `.autopilot.pid`), or press `Ctrl+C` in the terminal. On exit, `run.sh` automatically kills all child processes (MCP servers, subagents, workers) to prevent orphans.

### Option 2: `/autopilot` Slash Command

The **slash command** runs within a single Claude session. Context accumulates between iterations, which can be useful for complex multi-step work where Claude needs to remember previous actions.

```bash
claude --dangerously-skip-permissions
/autopilot docs/tasks/prds/feature.json
```

**How it works:**
1. Creates a loop state file with the task prompt
2. Claude works through requirements sequentially
3. The stop-hook intercepts exit attempts and re-feeds the prompt
4. Context accumulates (Claude remembers previous work)
5. Continues until COMPLETE is output or max iterations reached

**Options:**
```bash
/autopilot tasks.json                  # Use default iterations (15)
/autopilot tasks.json 30               # Override to 30 iterations
/autopilot tasks.json --batch 1        # Complete 1 requirement then stop
/autopilot tasks.json --start-from 5   # Resume from requirement 5
```

**When to use:**
- Small task files (1-4 requirements)
- Interactive sessions where you're watching
- When requirements build on each other and shared context helps
- Quick fixes or single features

### Which Should I Use?

**Use `autopilot` (bash) when:**
- You have many requirements to complete
- You're stepping away and want it to run autonomously
- Token efficiency matters
- You've hit context limits with `/autopilot` before

**Use `/autopilot` when:**
- You have a small, focused task
- You're actively monitoring progress
- Requirements are interdependent and benefit from shared context
- You want to use `--start-from` to resume mid-file

### Step 0: Initialize Project (One-Time)

Before using autopilot in a new project, initialize the configuration:

```bash
/autopilot init
```

This command:
1. **Checks your environment** - Verifies git is clean, detects installed tools
2. **Analyzes your codebase** - Detects project type, test patterns, architecture
3. **Configures feedback loops** - Finds your test/lint/typecheck commands
4. **Creates `autopilot.json`** - Saves all settings for autopilot to use

You only need to run this once per project. The resulting `autopilot.json` should be committed to your repository.

**Quick setup with auto-detected values:**
```bash
/autopilot init --force
```

### Step 1: Create PRD

```bash
/prd Add user authentication with email/password
```

Claude asks 3-5 clarifying questions, then generates a markdown PRD at `docs/tasks/prds/feature-name.md`.

**Review and revise until satisfied.** This is your chance to shape the feature before autonomous execution.

### Step 2: Generate Tasks

```bash
/tasks docs/tasks/prds/user-auth.md
```

Before generating tasks, `/tasks` **analyzes your codebase** to understand what exists:

1. **Phase 0: Codebase Analysis** - Searches for related files, patterns, and utilities
2. **Phase 1: Gap Analysis** - For each requirement, determines if it's `create`, `extend`, `modify`, or `already-done`
3. **Phase 2: Task Generation** - Creates enriched JSON with code-aware context
4. **Phase 3: Dependency Inference** - Auto-detects dependencies between requirements

Each requirement includes a `codeAnalysis` object with specific file targets and an `acceptance` array defining testable success criteria:

```json
{
  "requirements": [
    {
      "id": "1",
      "description": "User can register with email/password",
      "codeAnalysis": {
        "approach": "extend",
        "existingFiles": ["src/controllers/AuthController.ts"],
        "relatedTests": ["src/__tests__/auth.test.ts"],
        "patterns": ["Controllers extend BaseController"],
        "targetFiles": {
          "modify": ["src/controllers/AuthController.ts"],
          "create": ["src/models/User.ts"]
        }
      },
      "acceptance": [
        "POST /auth/register returns 201 with JWT on valid input",
        "Invalid email returns 400 with validation error",
        "Duplicate email returns 409 conflict"
      ],
      "tdd": {
        "test": { "description": "Add registration tests covering all acceptance criteria", "passes": false },
        "implement": { "description": "Extend AuthController with register endpoint", "passes": false },
        "refactor": { "passes": false }
      },
      "passes": false
    }
  ]
}
```

**Acceptance criteria** define what "done" means for each requirement. Each criterion becomes a test case in the TDD Red phase—Claude must write tests covering ALL acceptance criteria before proceeding to implementation.

**Refresh mode:** If implementation goes off-track, re-analyze with `--refresh`:

```bash
/tasks docs/tasks/prds/user-auth.json --refresh
```

This preserves completed requirements while re-running gap analysis on incomplete ones.

### Step 3: Enable Sandbox

```bash
/sandbox
```

Enables [sandbox mode](https://docs.anthropic.com/en/docs/claude-code/security#sandbox-mode). This is optional but advised for autonomous runs - it restricts file and network access so Claude can execute commands without permission prompts while your system stays protected.

### Step 4: Run Autopilot

```bash
/autopilot docs/tasks/prds/user-auth.json
```

Claude executes each requirement using TDD:

1. **Red** - Write failing test, verify it fails, commit
2. **Green** - Write minimal implementation, verify it passes, commit
3. **Refactor** - Run code-simplifier, verify tests green, commit

Progress is logged to `*-notes.md` alongside the task file. Learnings are appended to `AGENTS.md`.

## Autopilot Modes

| Command | Description |
|---------|-------------|
| `/autopilot init` | Initialize project configuration (one-time setup) |
| `/autopilot stop` | Stop run.sh wrapper gracefully |
| `/autopilot cancel` | Cancel hook-based loop (remove state file) |
| `/autopilot file.json [N]` | TDD task completion (default: 15 iterations) |
| `/autopilot file.json --start-from 5` | Resume from requirement ID 5 |
| `/autopilot rollback 3` | Rollback to before requirement 3 started |
| `/autopilot tests [target%] [N]` | Increase test coverage (default 80%, 10 iterations) |
| `/autopilot lint [N]` | Fix all lint errors one by one (default: 15 iterations) |
| `/autopilot entropy [N]` | Clean up code smells and dead code (default: 10 iterations) |
| `/autopilot analyze` | Analyze session analytics for improvement suggestions |
| `/autopilot /<command> --max N` | Run any slash command in a loop (default: 10 iterations) |

Pass an optional number `N` to override the default iterations from `autopilot.json`. Lower defaults optimize for token frugality.

### Command Loop Mode

Run any slash command repeatedly with fresh sessions:

```bash
# Via run.sh (recommended - fresh context per iteration)
autopilot /my-command --max 5           # Run /my-command 5 times
autopilot /review-pr 123 --max 3        # Run /review-pr with args, 3 times

# Via /autopilot directly (single session)
/autopilot /my-command --max 5          # Run in loop within session
```

**Use cases:**
- Repetitive tasks that benefit from fresh context each run
- Batch processing with a custom slash command
- Running a review or analysis command multiple times

**Note:** Use `--max N` to specify iterations. Without it, defaults to 10.

## How It Works

### Context and State Management

When using `/autopilot` directly, the built-in loop mechanism runs within a single session—**context accumulates** between iterations. This is by design: Claude can see its previous work and self-correct. However, this means long-running tasks may hit context limits.

**To avoid context limits, use `autopilot` (bash)** which starts fresh sessions for each requirement. See [Two Ways to Run Autopilot](#two-ways-to-run-autopilot) above.

Regardless of which method you use, Claude tracks progress through persistent state:
- Reading the task file (completed items marked `passes: true`)
- Reading the notes file (progress log with timestamps)
- Checking git history (all commits from previous iterations)

This persistent state allows seamless resumption across sessions.

### Token Frugality

Autopilot is optimized for token efficiency:

1. **Low iteration defaults** - Defaults are 10-15 iterations per session. Restart frequently for fresh context.
2. **Read notes first** - Each iteration reads the notes file first to understand current state, avoiding redundant exploration.
3. **Structured notes** - Notes maintain a "Current State" section for quick state reconstruction.
4. **Concise mode** - Claude is instructed to act without explaining, minimizing output tokens.
5. **Targeted reads** - Uses line ranges instead of reading entire files when possible.

### Subagent Parallelization

Claude uses subagents strategically based on the task type:

| Task Type | Strategy | Why |
|-----------|----------|-----|
| File reading | Parallel | No side effects, can read many files at once |
| Grep/search | Parallel | Independent searches, faster exploration |
| Codebase analysis | Parallel | Study multiple areas simultaneously |
| Tests | Sequential | Need to see results before deciding next step |
| Builds | Sequential | Must complete before validating |
| Commits | Sequential | Require backpressure and verification |

**Rule of thumb:** Reading and exploring uses parallel subagents for speed. Writing and executing uses sequential flow with feedback loops.

### Managing Context Limits

**Recommended: Use `autopilot` (bash)** for automatic context management. It handles everything for you.

If using `/autopilot` directly:

1. **Use `--batch 1`** - Complete one requirement per session: `/autopilot tasks.json --batch 1`
2. **Break large task files** - 5-7 requirements per JSON file works well
3. **Restart frequently** - End the session and run `/autopilot` again. Claude reads the JSON and notes file, then continues from where it left off.

Example manual workflow:
```bash
/autopilot tasks.json --batch 1   # Complete 1 requirement
# Session ends
/autopilot tasks.json --batch 1   # Fresh context, next requirement
```

Or let `autopilot` (bash) handle this automatically:
```bash
autopilot tasks.json         # Handles everything, fresh context each requirement
```

### Feedback Loops

Before every commit, autopilot runs:
- `typecheck` - TypeScript compiler
- `tests` - Test suite
- `lint` - Linter

If any fail, Claude fixes the issue before committing.

### Code Simplifier

During the TDD refactor phase, the `code-simplifier` agent runs to improve clarity and maintainability while preserving functionality.

### Stuck Handling

To prevent infinite loops on intractable problems, autopilot includes stuck detection:

1. **Detection** - Same task/error failing for 3 consecutive iterations
2. **Action** - Log the blocker with details to the notes file
3. **Recovery** - Mark task as `stuck: true`, skip to next task
4. **Completion** - Output COMPLETE when done or only stuck items remain

Stuck tasks are logged with a `blockedReason` so you can review and fix manually later.

### Thrashing Detection

**Thrashing** occurs when the same error repeats without meaningful progress—like trying to connect to a database 30 times when the sandbox is blocking the port. This wastes tokens on a fundamentally unsolvable problem.

Autopilot detects thrashing by tracking consecutive identical errors:

1. **Track errors** - Each error is normalized (timestamps/UUIDs stripped) and compared
2. **Detect repetition** - If the same error appears 3+ times consecutively (configurable via `analytics.thrashingThreshold`)
3. **Abort early** - Immediately mark the task as `stuck` with the thrashing pattern

Common thrashing patterns and fixes:

| Pattern | Likely Cause | Fix |
|---------|--------------|-----|
| `ECONNREFUSED localhost:*` | Sandbox blocking ports | Set `sandbox: false` in feedback loop |
| `Cannot find module` | Missing dependency | Run `npm install` |
| Same test assertion failing | Logic error | Re-read requirement |

### Session Analytics

Autopilot tracks per-session analytics to help identify token waste and improvement opportunities.

**What's tracked:**
- Iterations per requirement
- Errors with type and message
- Thrashing events
- Files read/written
- TDD phase timing

**Analytics files** are stored in `docs/tasks/analytics/` with names like `2026-01-10-user-auth-1.json`.

**Analyze sessions:**
```bash
/autopilot analyze                    # All sessions
/autopilot analyze --last             # Most recent only
/autopilot analyze --since 7d         # Last 7 days
/autopilot analyze --task user-auth   # Specific task
```

The analysis generates:
- **Efficiency score** - Productive vs wasted iterations
- **Waste patterns** - Thrashing, environment issues, missing context
- **Suggested fixes** - Proposed AGENTS.md entries and autopilot.json changes

Suggestions are printed to console for you to review and apply manually. After applying learnings, delete the analytics files:
```bash
rm docs/tasks/analytics/*.json
# or
/autopilot analyze --clear
```

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

### Resume and Rollback

Autopilot creates git tags before starting each requirement, enabling safe recovery:

**Resume from a specific requirement:**
```bash
# Skip requirements 1-4, start from requirement 5
/autopilot tasks.json --start-from 5
```

**Rollback to before a requirement started:**
```bash
# Undo all changes from requirement 3 onward
/autopilot rollback 3
```

Tags are named `autopilot/req-{id}/start` and automatically cleaned up when requirements complete successfully.

### Completion Summary

When autopilot finishes, it outputs a summary including:
- Requirements completed vs stuck
- Commits made with short descriptions
- Files created or modified
- Any blockers encountered

The summary is also appended to the notes file for reference.

### Notifications

Configure notifications in `autopilot.json` to be alerted when autopilot completes:

```json
{
  "notifications": {
    "enabled": true,
    "command": "notify-send 'Autopilot' 'Completed!'",
    "webhook": "https://your-webhook.com/endpoint",
    "ntfy": { "topic": "my-autopilot" }
  }
}
```

## File Structure

```
autopilot/                    # This repo (source of truth)
├── commands/
│   ├── prd.md               # /prd command
│   ├── tasks.md             # /tasks command
│   ├── autopilot.md         # /autopilot command
│   ├── autopilot:init.md    # /autopilot init command
│   └── analyze.md           # /autopilot analyze command
├── hooks/
│   ├── stop-hook.sh         # Loop mechanism (intercepts exit, re-feeds prompt)
│   └── hooks.json           # Hook configuration template
├── examples/
│   ├── brainstorm.md              # Example feature brainstorm
│   ├── prd-user-auth.md           # Example PRD document
│   ├── tasks-user-auth.json       # Example task file with TDD phases
│   ├── notes-user-auth.md         # Example progress notes
│   ├── analytics-user-auth-session.json  # Example session analytics
│   ├── autopilot-monorepo.json    # Example monorepo configuration
│   └── tasks-monorepo.json        # Example monorepo task file
├── autopilot.template.json  # Template for autopilot.json
├── autopilot.schema.json    # JSON schema for autopilot.json
├── analytics.schema.json    # JSON schema for session analytics
├── tasks.schema.json        # JSON schema for task files
├── run.sh                   # Token-frugal wrapper script
├── cleanup.sh               # Kill orphaned Claude Code processes
├── AGENTS.md                # Global agent guidelines (TDD, quality)
├── install.sh               # Creates symlinks to ~/.claude/
└── README.md

~/.claude/                   # Symlinks created by install.sh
├── commands/
│   ├── prd.md → repo
│   ├── tasks.md → repo
│   ├── autopilot.md → repo
│   ├── autopilot:init.md → repo
│   └── analyze.md → repo
├── hooks/
│   └── autopilot-stop-hook.sh → repo  # Loop mechanism
├── hooks.json               # Hook configuration (created by install.sh)
└── AGENTS.md → repo

your-project/                # Generated during workflow
├── autopilot.json           # Project configuration (created by /autopilot init)
└── docs/tasks/
    ├── analytics/           # Session analytics (auto-generated)
    │   └── 2026-01-10-feature-1.json
    └── prds/
        ├── feature.md       # Human-readable PRD
        ├── feature.json     # Machine-readable tasks
        └── feature-notes.md # Progress log (auto-generated)
```

## Configuration: autopilot.json

The `autopilot.json` file stores project-specific settings. Created by `/autopilot init`, it should be committed to your repository.

```json
{
  "$schema": "https://raw.githubusercontent.com/Gens-ai/autopilot/main/autopilot.schema.json",
  "version": "1.0.0",
  "project": {
    "type": "nodejs",
    "conventions": {
      "testFilePattern": "*.test.ts",
      "testDirectory": "src/__tests__",
      "sourceDirectory": "src"
    }
  },
  "feedbackLoops": {
    "typecheck": { "command": "npm run typecheck", "enabled": true },
    "tests": { "command": "npm test", "enabled": true },
    "lint": { "command": "npm run lint", "enabled": true }
  },
  "iterations": {
    "tasks": 15,
    "tests": 10,
    "lint": 15,
    "entropy": 10,
    "command": 10
  },
  "server": {
    "type": "github",
    "owner": "your-org",
    "repo": "your-repo",
    "mcp": "github"
  },
  "codebase": {
    "patterns": ["React", "TypeScript", "Express"],
    "architecture": "Monolith with React frontend and Express API",
    "dependencies": ["PostgreSQL", "Redis"]
  }
}
```

### Configuration Fields

| Field | Description |
|-------|-------------|
| `project.type` | Project language/framework (nodejs, python, go, etc.) |
| `project.conventions` | Test file patterns and directory locations |
| `feedbackLoops` | Commands for typecheck, tests, and lint |
| `iterations` | Default max iterations per mode |
| `server` | Git server info for MCP integration |
| `codebase` | Discovered patterns and architecture notes |

### Manual Configuration

You can edit `autopilot.json` directly to:
- Adjust iteration limits for your workflow
- Change feedback loop commands
- Disable specific feedback loops (`"enabled": false`)
- Disable sandbox per feedback loop (`"sandbox": false`) for database/Docker tests
- Add architecture notes for Claude to reference

### Advanced Configuration

**Baseline failures** - If your project has pre-existing issues, configure baselines to avoid blocking:
```json
{
  "baseline": {
    "typecheck": { "errorCount": 5 },
    "tests": { "failingTests": ["flaky-test-name"] },
    "lint": { "errorCount": 10 }
  }
}
```

**Test types** - Requirements can specify different test types with separate commands:
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

**Monorepo support** - Configure per-package feedback loops:
```json
{
  "workspaces": {
    "enabled": true,
    "packages": {
      "api": { "path": "packages/api", "feedbackLoops": { "tests": { "command": "npm test -w api" } } },
      "web": { "path": "packages/web", "feedbackLoops": { "tests": { "command": "npm test -w web" } } }
    }
  }
}
```

Then in your task file, scope requirements to specific packages:
```json
{
  "id": "5",
  "description": "Add user authentication API",
  "package": "api"
}
```

See `examples/autopilot-monorepo.json` and `examples/tasks-monorepo.json` for complete examples.

## Tips

- **Start with HITL**: Watch the first few iterations before going AFK
- **Approve tools once**: When prompted, choose "Always allow" for the session
- **Review commits**: Check git history when you return
- **Stop the wrapper**: Use `/autopilot stop` to stop run.sh, or Ctrl+C in that terminal
- **Cancel the loop**: Use `/autopilot cancel` to stop the hook-based loop mid-session
- **Keep PRDs small**: Smaller scope = better results
- **Use Sonnet for speed**: `--model sonnet` is faster and cheaper for straightforward tasks; save Opus for complex reasoning

## Troubleshooting

### Orphaned Claude processes accumulating

**Symptom:** System memory fills up, new Claude sessions get `Killed`, `ps aux | grep claude` shows dozens of old processes.

**Cause:** Claude Code spawns child processes (MCP servers, subagents, bun workers) that can outlive the parent session, especially when sessions are interrupted or force-killed. MCP servers started with `--daemon` double-fork and reparent to init, making them invisible to simple `kill` commands.

**Automatic prevention:** `run.sh` now kills the entire process tree after every session and on exit (Ctrl+C, SIGTERM, normal exit). This includes a sweep for daemonized processes that escaped the tree.

**Manual cleanup:**
```bash
# Kill background orphans only (safe - won't touch your interactive session)
autopilot-cleanup

# Preview what would be killed
autopilot-cleanup --dry-run

# Kill ALL Claude-related processes (including terminal-attached)
autopilot-cleanup --all

# Pre-run cleanup with autopilot
autopilot tasks.json --cleanup
```

### Stop hook firing repeatedly

If you cancel mid-run, the stop hook may fire multiple times as iterations unwind. This is normal - just wait for it to settle.

### Loop not starting

Ensure the hooks are installed correctly:
1. Check that `~/.claude/hooks/autopilot-stop-hook.sh` exists
2. Check that `~/.claude/hooks.json` includes the autopilot stop hook
3. Re-run `./install.sh` if needed

### Task file not found

Ensure the task file path is correct and the file exists. Common locations:
- `docs/tasks/prds/<feature>.json`
- `tasks/<feature>.json`

Run `/tasks <prd-file.md>` to generate a task file from a PRD.

### Tests not running

Ensure your project has commands for the feedback loops. Examples:

**Node.js (package.json)**
```json
{ "scripts": { "test": "jest", "typecheck": "tsc --noEmit", "lint": "eslint ." } }
```

**Python**
```bash
pytest                # tests
ruff check .          # lint
mypy .                # typecheck
```

**Go**
```bash
go test ./...         # tests
golangci-lint run     # lint
```

Claude will discover and use whatever commands are appropriate for your project.

### Missing jq dependency

If you see "jq: command not found" when running `autopilot` (bash wrapper):

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Fedora
sudo dnf install jq

# Arch
sudo pacman -S jq
```

### Tests fail with "ECONNREFUSED localhost:5432"

**Symptom:** Tests fail with connection errors even though Docker/database is running.

**Cause:** Claude Code's sandbox blocks Docker port forwarding.

**Solution:** Set `sandbox: false` for the tests feedback loop in `autopilot.json`:
```json
"feedbackLoops": {
  "tests": {
    "command": "npm test",
    "sandbox": false
  }
}
```

### Pre-existing test failures

**Symptom:** Autopilot won't commit because tests were already failing before you started.

**Solution:** Configure a baseline in `autopilot.json`:
```json
{
  "baseline": {
    "tests": { "failingTests": ["flaky-test-name"] },
    "lint": { "errorCount": 5 }
  }
}
```

Autopilot will only fail on NEW errors beyond the baseline. Ideally, fix pre-existing failures before using autopilot.

### Session interrupted mid-requirement

**Symptom:** Claude exited or crashed while working on a requirement.

**Recovery:**
1. Check the notes file (`*-notes.md`) for last known state
2. Check git log for any partial commits
3. If needed, rollback: `/autopilot rollback <requirement-id>`
4. Resume: `/autopilot tasks.json --start-from <requirement-id>`

### Circular dependencies between requirements

**Symptom:** Requirements depend on each other and none can start.

**Solution:** Review your task file and break the cycle:
1. Identify the circular chain (A → B → C → A)
2. Find which requirement can be made independent
3. Remove or change the `dependsOn` field to break the cycle
4. Re-run autopilot

### Requirement stuck but not obviously broken

**Symptom:** A requirement is marked `stuck: true` but the error isn't clear.

**Debugging steps:**
1. Read the `blockedReason` in the task JSON
2. Check the notes file for detailed error logs
3. Check analytics files in `docs/tasks/analytics/` for error patterns
4. Try running the test command manually to reproduce
5. Use `/autopilot rollback <id>` to reset and try again with modifications

### Context limits reached

**Symptom:** Claude's responses degrade or it starts forgetting previous work.

**Solutions:**
1. Use `autopilot` (bash wrapper) instead of `/autopilot` for automatic fresh context
2. Add `--batch 1` to complete one requirement per session
3. Break large task files into smaller ones (5-7 requirements each)
4. Restart Claude Code and resume with `--start-from`

### Invalid test detected (test passes before implementation)

**Symptom:** Requirement marked `invalidTest: true` in the task JSON.

**Causes:**
1. Feature already exists in the codebase
2. Test isn't actually testing the new behavior
3. Test assertion is incorrect

**Solution:** Review the test, fix it, then clear `invalidTest` and `invalidTestReason` from the JSON to retry.

### Thrashing detected

**Symptom:** Same error repeating multiple times, requirement marked stuck.

**Common causes and fixes:**

| Error Pattern | Cause | Fix |
|--------------|-------|-----|
| `ECONNREFUSED` | Sandbox blocking ports | Set `sandbox: false` |
| `Cannot find module` | Missing dependency | Run `npm install` |
| `ETIMEOUT` | Network unavailable | Check external services |
| Same assertion | Logic error | Re-read requirement |

### Analytics not generating

**Symptom:** No files appearing in `docs/tasks/analytics/`.

**Check:**
1. Ensure `analytics.enabled: true` in `autopilot.json`
2. Create the directory: `mkdir -p docs/tasks/analytics`
3. Check directory permissions

## Uninstall

Remove the symlinks:

```bash
rm ~/.claude/commands/{prd,tasks,autopilot,autopilot:init,analyze}.md ~/.claude/AGENTS.md
rm ~/.local/bin/autopilot ~/.local/bin/autopilot-cleanup
rm ~/.claude/hooks/autopilot-stop-hook.sh
```

You may also want to remove the autopilot entry from `~/.claude/hooks.json` if you have other hooks configured.

Then delete the repo folder.

## License

MIT
