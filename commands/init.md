# Autopilot Init

Initialize this project for autopilot by detecting project configuration and creating `autopilot.json`.

## Overview

This command performs comprehensive project analysis and setup:

1. **Pre-flight checks** - Verify environment is ready
2. **Codebase analysis** - Detect project type and conventions
3. **Server configuration** - Detect git remote and server type
4. **Configuration file** - Create or update `autopilot.json`
5. **Validation** - Verify all settings work

## Execution Steps

Execute these steps in order. After each section, update progress and continue to the next.

---

### Step 1: Pre-flight Checks

Perform these checks and report results:

#### 1.1 Git Working Directory

Run `git status --porcelain` to check for uncommitted changes.

- **If clean**: Report "Git working directory is clean"
- **If dirty**: Warn the user about uncommitted changes. Ask if they want to continue anyway. If they say no, stop initialization.

#### 1.2 Required Tools Detection

Check which development tools are available. Run these commands to detect installed tools:

**Package managers:**
- `npm --version` - Node.js npm
- `yarn --version` - Yarn
- `pnpm --version` - pnpm
- `pip --version` or `pip3 --version` - Python pip
- `poetry --version` - Poetry
- `go version` - Go
- `cargo --version` - Rust Cargo
- `bundle --version` - Ruby Bundler
- `composer --version` - PHP Composer

**Test runners:**
- Check package.json scripts for `test`, `jest`, `vitest`, `mocha`
- Check for `pytest.ini`, `pyproject.toml` with pytest, `setup.cfg` with pytest
- Check for `*_test.go` files (Go testing)
- Check for `Cargo.toml` (Rust testing)
- Check for `spec/` directory (RSpec)

**Linters:**
- Check for `.eslintrc*`, `eslint.config.*` (ESLint)
- Check for `ruff.toml`, `pyproject.toml` with ruff (Ruff)
- Check for `.golangci.yml` (golangci-lint)
- Check for `.rubocop.yml` (RuboCop)
- Check for `phpcs.xml` (PHP CodeSniffer)

**Type checkers:**
- Check for `tsconfig.json` (TypeScript)
- Check for `mypy.ini`, `pyproject.toml` with mypy (mypy)

Report found tools.

#### 1.3 Feedback Loop Detection

Based on detected tools, determine the feedback loop commands:

**For Node.js/TypeScript projects:**
1. Read `package.json` scripts section
2. Look for scripts named: `test`, `typecheck`, `type-check`, `tsc`, `lint`, `eslint`
3. Construct commands like `npm run test`, `npm run lint`, `npm run typecheck`
4. If no typecheck script but `tsconfig.json` exists, use `npx tsc --noEmit`

**For Python projects:**
1. Check for pytest: `pytest`
2. Check for ruff: `ruff check .`
3. Check for mypy: `mypy .`

**For Go projects:**
1. Tests: `go test ./...`
2. Lint: `golangci-lint run` (if config exists) or `go vet ./...`
3. Type check: Go compiler handles this

**For other projects:**
Detect based on config files found.

#### 1.4 Warning for Missing Feedback Loops

If no test runner, linter, or type checker is detected:
- Warn the user: "No feedback loops detected. Autopilot works best with tests, linting, and type checking."
- Ask if they want to continue with limited feedback loops
- Suggest adding these tools to their project

---

### Step 2: Codebase Analysis

#### 2.1 Project Type Detection

Determine project type by checking for:

| File/Directory | Project Type |
|----------------|--------------|
| `package.json` | nodejs (or typescript if tsconfig.json exists) |
| `pyproject.toml` or `setup.py` | python |
| `go.mod` | go |
| `Cargo.toml` | rust |
| `Gemfile` | ruby |
| `composer.json` | php |
| `*.csproj` or `*.sln` | dotnet |
| `pom.xml` or `build.gradle` | java |

#### 2.2 Test File Conventions

Detect test file patterns:

**Node.js/TypeScript:**
- Look for `__tests__/` directory
- Look for `*.test.ts`, `*.test.tsx`, `*.spec.ts` files
- Check Jest/Vitest config for `testMatch` patterns

**Python:**
- Look for `tests/` directory
- Look for `test_*.py` or `*_test.py` files
- Check pytest config for `testpaths`

**Go:**
- Tests are `*_test.go` files alongside source
- No separate test directory convention

**Other languages:**
Detect based on common conventions.

#### 2.3 Source Directory

Identify main source directory:
- `src/` - Common for Node.js, TypeScript
- `lib/` - Common for Ruby, some Node.js
- `app/` - Common for Rails, some frameworks
- `.` (root) - Common for Go, Python, smaller projects

#### 2.4 Architecture Patterns

Analyze the codebase for patterns. Look for:

- **Frameworks**: React, Vue, Angular, Next.js, Express, FastAPI, Django, Rails, Gin, etc.
- **Architecture**: Monorepo (multiple package.json or go.mod), microservices, monolith
- **Patterns**: MVC, Clean Architecture, Domain-Driven Design
- **Key dependencies**: Database clients, API frameworks, testing libraries

Read key files like `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml` to understand dependencies.

Summarize in 1-2 sentences for the `architecture` field.

---

### Step 3: Server Configuration

#### 3.1 Git Remote Detection

Run `git remote -v` to detect remote repositories.

Parse the origin URL to extract:
- **Server type**: github, gitlab, bitbucket (from URL)
- **Owner**: Organization or username
- **Repo**: Repository name

Examples:
- `git@github.com:Gens-ai/autopilot.git` → github, Gens-ai, autopilot
- `https://github.com/user/repo.git` → github, user, repo
- `git@gitlab.com:org/project.git` → gitlab, org, project

#### 3.2 MCP Server Detection

Check if Claude has MCP servers configured that match the detected server type:
- For GitHub repos, check if GitHub MCP is available
- For GitLab repos, check if GitLab MCP is available

Ask the user: "Do you want to use [MCP server] for GitHub/GitLab integration? This enables issue tracking and PR creation. (y/n)"

If yes, record the MCP server name.
If no or not available, leave as null.

---

### Step 4: Configuration File Creation

#### 4.1 Check Existing Configuration

Check if `autopilot.json` already exists in the project root.

- **If exists**: Read it and ask "autopilot.json already exists. Do you want to (u)pdate it with new detections, (o)verwrite completely, or (s)kip? [u/o/s]"
- **If not exists**: Proceed to create new file

#### 4.2 Build Configuration Object

Construct the configuration based on all detected values:

```json
{
  "$schema": "https://raw.githubusercontent.com/Gens-ai/autopilot/main/autopilot.schema.json",
  "version": "1.0.0",
  "project": {
    "type": "<detected-type>",
    "conventions": {
      "testFilePattern": "<detected-pattern>",
      "testDirectory": "<detected-directory>",
      "sourceDirectory": "<detected-source>"
    }
  },
  "feedbackLoops": {
    "typecheck": {
      "command": "<detected-or-null>",
      "enabled": true
    },
    "tests": {
      "command": "<detected-or-null>",
      "enabled": true
    },
    "lint": {
      "command": "<detected-or-null>",
      "enabled": true
    }
  },
  "iterations": {
    "tasks": 50,
    "tests": 30,
    "lint": 50,
    "entropy": 30
  },
  "server": {
    "type": "<detected-type>",
    "owner": "<detected-owner>",
    "repo": "<detected-repo>",
    "mcp": "<detected-or-null>"
  },
  "codebase": {
    "patterns": ["<detected-patterns>"],
    "architecture": "<brief-description>",
    "dependencies": ["<key-deps>"]
  }
}
```

#### 4.3 Review with User

Present the configuration to the user for review:

```
Detected configuration:

Project: <type>
Source: <sourceDirectory>
Tests: <testDirectory> (<testFilePattern>)

Feedback loops:
  - typecheck: <command or "not detected">
  - tests: <command or "not detected">
  - lint: <command or "not detected">

Server: <type> (<owner>/<repo>)
MCP: <mcp or "not configured">

Architecture: <description>
Patterns: <patterns>

Does this look correct? (y)es to save, (e)dit to modify, (c)ancel
```

If user wants to edit, ask which field to change and update accordingly.

#### 4.4 Write Configuration

Write the configuration to `autopilot.json` in the project root.

---

### Step 5: Validation

#### 5.1 Validate Configuration

Read back `autopilot.json` and verify:
- JSON is valid
- Required fields are present
- Values are reasonable

#### 5.2 Test Feedback Loops

For each enabled feedback loop with a command:

1. Run the command
2. Report if it succeeds or fails
3. If it fails, warn the user and ask if they want to disable it or fix the command

Example:
```
Testing feedback loops...
  typecheck: npm run typecheck ... OK
  tests: npm test ... OK
  lint: npm run lint ... FAILED (exit code 1)

Lint command failed. This may be expected if there are existing lint errors.
Keep this feedback loop enabled? (y/n)
```

#### 5.3 Server Connection Test (Optional)

If MCP server is configured and user wants to test:
- Try a simple operation like listing repository info
- Report success or failure
- If failed, offer to remove MCP configuration

---

### Step 6: Completion

Report final status:

```
Autopilot initialization complete!

Configuration saved to: autopilot.json

Next steps:
1. Review autopilot.json and adjust if needed
2. Commit autopilot.json to your repository
3. Create a PRD with /prd <feature-description>
4. Convert to tasks with /tasks <prd-file>
5. Run /autopilot <tasks.json> to start autonomous development

Run /autopilot --help for all available commands.
```

---

## User Prompts

When information cannot be auto-detected, ask the user:

1. "What type of project is this?" - If no package manager config found
2. "Where are your test files located?" - If test pattern unclear
3. "What command runs your tests?" - If test command not in package.json/config
4. "What command runs your linter?" - If lint command not detected
5. "Do you use type checking? What command?" - If typecheck not detected

Keep questions minimal - only ask what can't be detected.

---

## Error Handling

- If not in a git repository: "This directory is not a git repository. Autopilot requires git for version control. Run `git init` first."
- If no write permission: "Cannot write autopilot.json. Check directory permissions."
- If user cancels: "Initialization cancelled. Run /autopilot init again when ready."

---

## Arguments

Parse `$ARGUMENTS` for optional flags:

- `--force` or `-f`: Skip confirmation prompts, use detected values
- `--skip-validation`: Skip feedback loop testing
- `--no-mcp`: Skip MCP server configuration

Example: `/autopilot init --force`

---

## Execution

Begin by announcing: "Initializing autopilot configuration for this project..."

Then execute each step in order, reporting progress as you go.

Parse arguments: $ARGUMENTS
