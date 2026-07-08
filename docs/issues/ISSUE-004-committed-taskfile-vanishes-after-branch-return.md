---
id: ISSUE-004
title: task file committed on feature branch vanishes from queue after branch-return checkout
status: resolved
created: 2026-07-08
resolved: 2026-07-08
---

## Summary

A queue entry can finish 100% successfully — real commits, all requirements passed — and still show as `missing` in `autopilot queue list` afterward, because the task JSON itself got swept into a commit on the feature branch instead of staying uncommitted, and queue mode's branch-return step (`git checkout $START_BRANCH`) correctly deletes any file that's tracked on the branch being left but absent from the branch being returned to.

## Details

- Found live: user ran the real `/prd` → `/tasks` → `autopilot` pipeline (not a fake/scripted session) in a disposable scratch project (`~/Dev/queue-test`), queuing three small features (subtract, multiply, divide) one after another.
- `subtract` and `multiply` finished and correctly showed `done`. `divide` finished (real commits: "test: add failing divide tests", "feat: implement divide in src/math.js", "chore: mark divide requirement 1 complete") but showed `missing` in `autopilot queue list` afterward.
- Root cause confirmed via `git ls-tree`: `docs/autopilot/divide/divide.json` was committed on the `divide` branch (as part of "chore: mark divide requirement 1 complete" — a commit whose apparent purpose was to persist the task file's own `passes: true` update) but never existed in `master`'s tree at all. `multiply.json`, by contrast, was left uncommitted the whole time (matching the intended convention), so it survived the same branch switch as an ordinary untracked file.
- `git checkout <branch>` behavior here is completely standard: when leaving a branch where a file is tracked, and returning to one where that path doesn't exist in the tree, git removes it from the working directory. Not a git bug — a task-file lifecycle gap in how autopilot's own TDD workflow instructs commits.

## Findings

- **2026-07-08:** Two-part fix.
  1. Root cause: `commands/autopilot.md`'s TDD Task Completion mode now explicitly instructs staging only the specific source/test files per requirement commit — never `git add -A`/`git add .`, and never the task file, notes file, or analytics directory (autopilot's own bookkeeping must stay uncommitted on the feature branch).
  2. Defense in depth: `run.sh`'s queue-mode branch-return step now runs `git checkout <feature-branch> -- <entry-dir>` immediately after switching back to the start branch — a best-effort restore of the entry directory from the feature branch's tree, so even a session that ignores the instruction above can't corrupt the queue's view of a genuinely-finished entry. No-op when the file was never committed on the feature branch (already survives as untracked content).
  3. Verified directly against the live corrupted state: ran the same restore command (`git checkout divide -- docs/autopilot/divide`) against the user's actual `~/Dev/queue-test` project and confirmed `autopilot queue list` immediately reported `divide` as `done` again with no data loss.

## Resolution

- **2026-07-08:** Fixed in `run.sh` and `commands/autopilot.md` — commit `4ca53ee`.
