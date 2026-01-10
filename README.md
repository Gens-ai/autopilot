# Autopilot: Autonomous TDD Development with Claude Code

A workflow for autonomous, test-driven development using Claude Code and the Ralph Loop plugin. Write a PRD, convert it to tasks, then let Claude implement everything using TDD while you sleep.

[![Watch the intro video](https://cdn.loom.com/sessions/thumbnails/741f5db667c4485c9571dc6ec1a5a994-ec7f0d3f91180f38-full-play.gif)](https://www.loom.com/share/741f5db667c4485c9571dc6ec1a5a994)

## Credits

This workflow is built on the [Ralph Wiggum](https://ghuntley.com/ralph/) approach by [Geoffrey Huntley](https://ghuntley.com/author/ghuntley/) (July 2025). Ralph runs your AI coding CLI in a loop, letting it work autonomously on a list of tasks.

Additional inspiration from this amazing video walkthrough by [Ryan Carson](https://www.youtube.com/watch?v=RpvQH0r0ecM) and his repo [snarktank/ai-dev-tasks](https://github.com/snarktank/ai-dev-tasks) for PRD and task generation prompts. Some tips were also applied from [Matt Pocock](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum).

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with an active subscription
- [Ralph Loop Plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) installed
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
- `~/.local/bin/autopilot` → repo/`autopilot` (terminal command)

Updates to the repo are automatically available (just `git pull`).

**Note:** Ensure `~/.local/bin` is in your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.bashrc or ~/.zshrc
```

### 3. Install Claude plugins

```bash
claude plugins:install claude-plugins-official
```

This installs the official Anthropic plugin collection, which includes:
- **ralph-loop** - Runs Claude in a loop for autonomous execution
- **code-simplifier** - Refactors code for clarity during TDD refactor phase

### 4. Restart Claude Code

Start a new Claude Code session for the commands to become available.

### 5. Verify installation

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
2. Invokes `claude --dangerously-skip-permissions "/autopilot <file> --batch 1"`
3. Claude completes one requirement, then exits
4. Script checks for remaining requirements
5. If more remain, starts a new Claude session (fresh context)
6. Repeats until all requirements are complete or stuck

**Why fresh context matters:**
- Claude Code's Ralph Loop accumulates context within a session
- After 5-10 requirements, context can exceed limits or degrade quality
- Fresh sessions mean Claude starts clean each time
- State is preserved in the task JSON and notes file, not in memory

**Options:**
```bash
autopilot tasks.json              # 1 requirement per session (most frugal)
autopilot tasks.json --batch 3    # 3 requirements per session (faster)
autopilot tasks.json --delay 5    # 5 second pause between sessions
autopilot tasks.json --dry-run    # Preview without executing
```

**When to use:**
- Task files with 5+ requirements
- Running overnight or unattended
- When you want maximum token efficiency
- Large codebases where context matters

### Option 2: `/autopilot` Slash Command

The **slash command** runs within a single Claude session. Context accumulates between iterations, which can be useful for complex multi-step work where Claude needs to remember previous actions.

```bash
claude --dangerously-skip-permissions
/autopilot docs/tasks/prds/feature.json
```

**How it works:**
1. Invokes Ralph Loop with your task file
2. Claude works through requirements sequentially
3. Context accumulates (Claude remembers previous work)
4. Continues until max iterations or all requirements done

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

Converts the PRD to a JSON file with structured requirements. Each requirement has TDD phases:

```json
{
  "requirements": [
    {
      "id": "1",
      "description": "User can register with email/password",
      "tdd": {
        "test": { "passes": false },
        "implement": { "passes": false },
        "refactor": { "passes": false }
      },
      "passes": false
    }
  ]
}
```

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
| `/autopilot file.json [N]` | TDD task completion (default: 15 iterations) |
| `/autopilot file.json --start-from 5` | Resume from requirement ID 5 |
| `/autopilot rollback 3` | Rollback to before requirement 3 started |
| `/autopilot tests [target%] [N]` | Increase test coverage (default 80%, 10 iterations) |
| `/autopilot lint [N]` | Fix all lint errors one by one (default: 15 iterations) |
| `/autopilot entropy [N]` | Clean up code smells and dead code (default: 10 iterations) |

Pass an optional number `N` to override the default iterations from `autopilot.json`. Lower defaults optimize for token frugality.

## How It Works

### Context and State Management

When using `/autopilot` directly, Ralph Loop runs within a single session—**context accumulates** between iterations. This is by design: Claude can see its previous work and self-correct. However, this means long-running tasks may hit context limits.

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
│   └── init.md              # /autopilot init command
├── examples/
│   ├── brainstorm.md        # Example feature brainstorm
│   ├── prd-user-auth.md     # Example PRD document
│   ├── tasks-user-auth.json # Example task file with TDD phases
│   └── notes-user-auth.md   # Example progress notes
├── autopilot.template.json  # Template for autopilot.json
├── autopilot.schema.json    # JSON schema for validation
├── `autopilot`             # Token-frugal wrapper script
├── AGENTS.md                # Global agent guidelines (TDD, quality)
├── install.sh               # Creates symlinks to ~/.claude/
└── README.md

~/.claude/                   # Symlinks created by install.sh
├── commands/
│   ├── prd.md → repo
│   ├── tasks.md → repo
│   ├── autopilot.md → repo
│   └── init.md → repo
└── AGENTS.md → repo

your-project/                # Generated during workflow
├── autopilot.json           # Project configuration (created by /autopilot init)
└── docs/tasks/
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
    "entropy": 10
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

## Tips

- **Start with HITL**: Watch the first few iterations before going AFK
- **Approve tools once**: When prompted, choose "Always allow" for the session
- **Review commits**: Check git history when you return
- **Use `/cancel-ralph`**: Stop the loop if needed
- **Keep PRDs small**: Smaller scope = better results

## Troubleshooting

### Stop hook firing repeatedly

If you cancel mid-run, the stop hook may fire multiple times as iterations unwind. This is normal - just wait for it to settle.

### Ralph not finding tasks

Ensure the task file path is correct and the file exists. Ralph reads the file at the start of each iteration.

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

## Uninstall

Remove the symlinks:

```bash
rm ~/.claude/commands/prd.md ~/.claude/commands/tasks.md ~/.claude/commands/autopilot.md ~/.claude/AGENTS.md
```

Then delete the repo folder.

## License

MIT
