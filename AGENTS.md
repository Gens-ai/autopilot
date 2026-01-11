# Agent Guidelines

## Test-Driven Development (TDD)

Always write tests BEFORE implementation:

1. **Red** - Write a failing test that defines expected behavior
2. **Green** - Write minimal code to make the test pass
3. **Refactor** - Clean up while keeping tests green

Never skip the red phase. If tests pass before implementation, your test isn't testing the right thing.

### TDD Pitfalls

- **Fixture conflicts**: Tests sharing fixtures can interfere. Use fresh fixtures per test or reset state between tests.
- **Test pollution**: Global state or database records from one test affecting another. Use transactions that rollback.
- **Flaky tests**: Fix immediately. Usually caused by timing issues, shared state, or external dependencies.

If tests fail unexpectedly, run in isolation first - if it passes alone, suspect shared state.

## Code Quality

- Fight entropy. Leave code better than you found it.
- No hacks without documenting WHY
- Follow existing patterns in the codebase
- The patterns you establish will be copied. The corners you cut will be cut again.

## Guardrails

Critical rules that must never be violated:

### Search Before Implementing
Don't assume something isn't implemented. Before creating new code:
1. Search the codebase for existing implementations
2. Check if you can extend existing code
3. Look for utilities that already do what you need

### No Placeholders
Implement fully or mark as stuck. Never:
- Leave TODO/FIXME comments in committed code
- Create placeholder functions or stub implementations
- Commit partial implementations

If blocked, mark `stuck: true` with a clear reason and move on.

### Single Source of Truth
No duplicate implementations. Prefer extending over creating parallel implementations. Consolidate duplicates discovered during refactor.

## Before Committing

- Run typecheck, tests, and lint
- Do NOT commit if any fail - fix first
- One logical change per commit

## Before Pushing

- Update CHANGELOG.md with notable changes
- Use date headers (## YYYY-MM-DD)
- Group by: Added, Changed, Fixed, Removed

---

*Document project-specific learnings in your notes file, not here. Keep AGENTS.md purely operational.*
