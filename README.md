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
/prd feature-name        → Human-readable PRD (you review)
/tasks prd-file.md       → Machine-readable JSON (for autopilot)
/sandbox                 → Enable sandbox mode (no permission prompts)
/autopilot tasks.json    → Autonomous TDD execution
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
| `/autopilot file.json` | TDD task completion (default) |
| `/autopilot tests 80` | Increase test coverage to 80% |
| `/autopilot lint` | Fix all lint errors one by one |
| `/autopilot entropy` | Clean up code smells and dead code |

## How It Works

### Context Reset Between Iterations

Ralph Loop clears context after each iteration. Claude sees progress by:
- Reading the task file (checked items show what's done)
- Reading the notes file (progress log)
- Checking git history

This prevents context bloat on long-running tasks.

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
│   └── autopilot.md         # /autopilot command
├── AGENTS.md                # Global agent guidelines (TDD, quality)
├── install.sh               # Creates symlinks to ~/.claude/
└── README.md

~/.claude/                   # Symlinks created by install.sh
├── commands/
│   ├── prd.md → repo
│   ├── tasks.md → repo
│   └── autopilot.md → repo
└── AGENTS.md → repo

your-project/                # Generated during workflow
└── docs/tasks/
    └── prds/
        ├── feature.md       # Human-readable PRD
        ├── feature.json     # Machine-readable tasks
        └── feature-notes.md # Progress log (auto-generated)
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
