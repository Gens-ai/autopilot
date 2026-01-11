# Agent Guidelines

## Test-Driven Development (TDD)

Always write tests BEFORE implementation:

1. **Red** - Write a failing test that defines expected behavior
2. **Green** - Write minimal code to make the test pass
3. **Refactor** - Clean up while keeping tests green

Never skip the red phase. If tests pass before you write implementation, your test isn't testing the right thing.

### Common TDD Pitfalls

**Fixture Conflicts**
- Tests sharing fixtures can interfere with each other
- Always check if fixtures are properly isolated
- Use fresh fixtures per test or reset state between tests
- If tests pass individually but fail together, suspect fixture pollution

**Test Pollution**
- Global state modified by one test can break subsequent tests
- Database records created in one test may affect another
- Clean up after tests or use transactions that rollback

**Flaky Tests**
- Tests that sometimes pass and sometimes fail are a red flag
- Common causes: timing issues, shared state, external dependencies
- Fix flaky tests immediately - they erode confidence in the test suite

**What To Do When Tests Fail Unexpectedly**
1. Run the failing test in isolation - does it pass alone?
2. Check for shared fixtures or global state
3. Look for database/file cleanup that might be missing
4. Check if another test is modifying shared resources
5. Consider adding explicit setup/teardown

## Code Quality

This codebase will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into technical debt that slows the whole team down.

- Fight entropy. Leave code better than you found it.
- No hacks or workarounds without documenting WHY
- Follow existing patterns in the codebase
- The patterns you establish will be copied. The corners you cut will be cut again.

## Guardrails

Critical rules that must never be violated:

### Search Before Implementing
Don't assume something isn't implemented. Before creating any new utility, component, or pattern:
1. Search the codebase for existing implementations
2. Check if you can extend existing code
3. Look for utilities that already do what you need

### No Placeholders
Implement fully or mark as stuck. Never:
- Leave TODO/FIXME comments in committed code
- Create placeholder functions or stub implementations
- Commit partial implementations

If blocked, mark the task as `stuck: true` with a clear reason and move on.

### Single Source of Truth
No duplicate implementations. Before writing new code:
1. Search for existing equivalent functionality
2. Prefer extending over creating parallel implementations
3. Consolidate duplicates discovered during refactor

## Before Committing

- Run typecheck, tests, and lint
- Do NOT commit if any fail - fix first
- Keep changes small and focused
- One logical change per commit

## Before Pushing

- Update CHANGELOG.md with notable changes
- Use date headers (## YYYY-MM-DD)
- Group by: Added, Changed, Fixed, Removed

## Learnings

Append learnings here as you discover project-specific gotchas. Categorize by type:

### Gotchas
Project-specific quirks and unexpected behaviors:
<!-- Example: - 2024-01-15: The auth module requires X before Y or it fails silently -->

### Patterns
Useful patterns discovered in this codebase:
<!-- Example: - 2024-01-16: Always use `fetchWithRetry` for external API calls -->

### Dependencies
Dependency-specific issues and workarounds:
<!-- Example: - 2024-01-17: Library X v2.0 has breaking change, pin to v1.9 -->

### Testing
Test-specific learnings:
<!-- Example: - 2024-01-18: Integration tests need DB_TEST_URL env var set -->

---

**When to add learnings:**
- After marking a requirement as stuck - document what blocked you
- After discovering an undocumented behavior
- After finding a workaround for a dependency issue
- After a test failure reveals a non-obvious cause

**Format:** `- YYYY-MM-DD: Brief description of the learning`
