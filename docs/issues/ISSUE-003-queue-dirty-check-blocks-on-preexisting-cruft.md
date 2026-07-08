---
id: ISSUE-003
title: queue drain blocks forever on pre-existing untracked cruft unrelated to autopilot
status: resolved
created: 2026-07-07
resolved: 2026-07-07
---

## Summary

The queue drain's dirty-tree check (already scoped to exclude autopilot's own bookkeeping per ISSUE-002) was still a single point-in-time snapshot with no baseline. Any pre-existing untracked or modified file in the repo — unrelated to autopilot, unrelated to the entry that just ran — would trip it and halt the drain after the very first entry, every time. This would make queue mode unreliable on any real-world repo that has ordinary untracked cruft (a stray log file, `.env.local`, editor droppings, etc.), defeating the "unattended overnight" purpose of the feature.

## Details

- Location: `run.sh`, queue-mode drain loop, the post-entry dirty-tree check (the same one hardened in ISSUE-002).
- Found while dogfooding the queue feature end-to-end in a disposable scratch project (`~/Dev/autopilot-dogfood-test`, deleted after testing) with the real installed `autopilot` CLI and real Claude sessions (haiku) completing real TDD requirements.
- Repro: redirected the wrapper's own stdout to a log file inside the project directory (`autopilot --delay 2 > drain.log 2>&1 &`, a natural thing to do for a background/overnight run) — `drain.log` is untracked, at the repo root, outside every ISSUE-002 exclusion (queue file, `.autopilot/`, entry dir). First entry finished correctly (real commit, requirement marked passed), but the drain then reported "Working tree is dirty ... stopping" and halted before touching the second queued entry, solely because of the unrelated log file.
- Confirmed the exclusion patterns from ISSUE-002 were working correctly on their own; the remaining gap was structural — a static check has no way to distinguish "cruft that was already there" from "cruft this entry just created."

## Findings

- **2026-07-07:** Fix: capture a `git status --porcelain` snapshot (with the ISSUE-002 exclusions) immediately before each entry starts, and after the entry finishes diff it against a fresh snapshot with `comm -13` — only paths that are dirty *after* but were not dirty *before* count as "new dirt" and halt the drain. Verified with a targeted re-test: planted an untracked `NOTES.local.txt` in the scratch repo before starting a fresh drain (simulating unrelated pre-existing cruft), and the second queued entry (`string-utils`) completed and committed normally, correctly ignoring the planted file.
- **2026-07-07:** Also cleaned up a cosmetic side effect noticed during the fix: `git checkout` prints an unlabeled `M\t<path>` merge report to stdout when it carries forward uncommitted bookkeeping edits (queue stamps, task-file `passes` flags) across the branch-return step. Added `-q` to that checkout call so the drain log doesn't show raw, unexplained diff-status lines.

## Resolution

- **2026-07-07:** Fixed in `run.sh` — commit `7b4622f`.
