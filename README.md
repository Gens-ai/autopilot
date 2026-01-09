# Autopilot: Autonomous TDD Development with Claude Code

A workflow for autonomous, test-driven development using Claude Code and the Ralph Loop plugin. Write a PRD, convert it to tasks, then let Claude implement everything using TDD while you sleep.

## Credits

This workflow is built on the [Ralph Wiggum](https://ghuntley.com/ralph/) approach by [Geoffrey Huntley](https://ghuntley.com/author/ghuntley/) (July 2025). Ralph runs your AI coding CLI in a loop, letting it work autonomously on a list of tasks.

Additional inspiration from this amazing video walkthrough by [Ryan Carson](https://www.youtube.com/watch?v=RpvQH0r0ecM) and his repo [snarktank/ai-dev-tasks](https://github.com/snarktank/ai-dev-tasks) for PRD and task generation prompts. Some tips were also applied from [Matt Pocock](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum).

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with an active subscription
- [Ralph Loop Plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) installed
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

This creates symlinks from the repo to `~/.claude/`:
- `~/.claude/commands/prd.md` → repo
- `~/.claude/commands/tasks.md` → repo
- `~/.claude/commands/autopilot.md` → repo
- `~/.claude/AGENTS.md` → repo

Updates to the repo are automatically available (just `git pull`).

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

### Pro Tip: Let it fly

If you really want to sleep or go for a walk outside while autopilot builds your features, you'll need to tell Claude to skip permission prompts. Use this carefully. You might want to spin up a VM to run this in if you want to be optimally careful. Start your Claude session with;

```bash
claude --dangerously-skip-permissions
```

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

Enables [sandbox mode](https://docs.anthropic.com/en/docs/claude-code/security#sandbox-mode) so autopilot can run without permission prompts. Your system files are protected.

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
| `/autopilot tests [target%] [N]` | Increase test coverage (default 80%, 10 iterations) |
| `/autopilot lint [N]` | Fix all lint errors one by one (default: 15 iterations) |
| `/autopilot entropy [N]` | Clean up code smells and dead code (default: 10 iterations) |

Pass an optional number `N` to override the default iterations from `autopilot.json`. Lower defaults optimize for token frugality.

## How It Works

### Context Accumulation Between Iterations

Ralph Loop runs within a single session—**context accumulates** between iterations. This is by design: Claude can see its previous work and self-correct. However, this means long-running tasks may hit context limits.

Claude tracks progress through persistent state:
- Reading the task file (completed items marked `passes: true`)
- Reading the notes file (progress log with timestamps)
- Checking git history (all commits from previous iterations)

### Token Frugality

Autopilot is optimized for token efficiency:

1. **Low iteration defaults** - Defaults are 10-15 iterations per session. Restart frequently for fresh context.
2. **Read notes first** - Each iteration reads the notes file first to understand current state, avoiding redundant exploration.
3. **Structured notes** - Notes maintain a "Current State" section for quick state reconstruction.
4. **Concise mode** - Claude is instructed to act without explaining, minimizing output tokens.
5. **Targeted reads** - Uses line ranges instead of reading entire files when possible.

### Managing Context Limits

To avoid hitting context limits on large tasks:

1. **Break large task files into batches** - 5-7 requirements per JSON file works well.
2. **Restart on the same file** - When context gets heavy, end the session and run `/autopilot` again on the same task file. Claude reads the JSON and notes file, then continues from where it left off.
3. **Custom iterations** - Pass a number to override the default: `/autopilot tasks.json 10`

Example workflow for large features:
```bash
/autopilot tasks.json       # Run with default 15 iterations
# Session ends or gets heavy
/autopilot tasks.json       # Fresh context, continues from completed tasks
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

## File Structure

```
autopilot/                    # This repo (source of truth)
├── commands/
│   ├── prd.md               # /prd command
│   ├── tasks.md             # /tasks command
│   ├── autopilot.md         # /autopilot command
│   └── init.md              # /autopilot init command
├── autopilot.template.json  # Template for autopilot.json
├── autopilot.schema.json    # JSON schema for validation
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
- Add architecture notes for Claude to reference

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
