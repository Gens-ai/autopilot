# Agent Guidelines

## Test-Driven Development (TDD)

Always write tests BEFORE implementation:

1. **Red** - Write a failing test that defines expected behavior
2. **Green** - Write minimal code to make the test pass
3. **Refactor** - Clean up while keeping tests green

Never skip the red phase. If tests pass before you write implementation, your test isn't testing the right thing.

## Code Quality

This codebase will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into technical debt that slows the whole team down.

- Fight entropy. Leave code better than you found it.
- No hacks or workarounds without documenting WHY
- Follow existing patterns in the codebase
- The patterns you establish will be copied. The corners you cut will be cut again.

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

Append learnings here as you discover project-specific gotchas:

<!-- Example:
- 2024-01-15: The auth module requires X before Y or it fails silently
- 2024-01-16: Always use `fetchWithRetry` for external API calls
-->
