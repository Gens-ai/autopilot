---
id: ISSUE-002
title: queue drain falsely detects a dirty working tree between every entry
status: open
created: 2026-07-07
---

## Summary

The queue drain loop in `run.sh` would have halted after the very first entry on every run, mistaking autopilot's own bookkeeping writes for leftover uncommitted feature work — defeating the entire point of queue mode (unattended draining of multiple task files).

## Details

- Location: `run.sh`, queue-mode drain loop, the git-status check that runs after each entry finishes (before returning to the starting branch and moving to the next queue entry).
- The check ran `git status --porcelain` with no exclusions, intending to catch "did the entry leave uncommitted feature work behind."
- In practice it also caught autopilot's own housekeeping between entries: `queue.json` stamp updates (`startedAt`/`completedAt` written by `autopilot-queue stamp`), the entry's notes/analytics files, and `.autopilot/` lock files — none of which indicate a problem.
- As written, this would have stopped the drain after literally every entry, not just ones that actually left dirty state.
- Found during pre-commit testing: ran a real end-to-end drain (fake `claude` binary completing requirements and committing) across three queued task files, and watched the drain stop after the first entry with a dirty-tree warning even though the only uncommitted change was `queue.json`'s stamp update.
- Neither this feature nor the bug has shipped yet — caught in manual end-to-end testing before commit, not a production incident.

## Findings

- **2026-07-07:** Fix applied in the working tree (not yet committed): scope the git status check to exclude the queue file, the `.autopilot/` directory, and the entry's own task-file directory: `git status --porcelain -- . ":(exclude)$QUEUE_FILE" ":(exclude).autopilot" ":(exclude)$ENTRY_DIR"`. Re-ran the same three-entry drain test afterward and it completed all three entries without a false dirty-tree stop.
