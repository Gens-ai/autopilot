---
id: ISSUE-001
title: queue list command exits nonzero, breaks under set -e
status: resolved
created: 2026-07-07
resolved: 2026-07-07
---

## Summary

`autopilot queue list` crashed instead of printing "Nothing runnable" whenever the queue had no runnable entries (all done, stuck, or on hold). Callers of `list` (`status.sh`, `run.sh`'s queue-mode banner) would have inherited the failure under `set -e`.

## Details

- Location: `autopilot-queue`, `cmd_list()` calling `cmd_next()`.
- `cmd_next()` calls `exit 2` by design when nothing is runnable, so callers can distinguish "found a task" from "queue empty".
- `cmd_list()` called it as: `next_tf=$(cmd_next 2>/dev/null || true)`.
- The `|| true` sits *inside* the command substitution's subshell. `exit 2` terminates that subshell immediately — there's no shell left to evaluate `|| true` against — so the substitution itself returns exit code 2, uncaught, which crashes `list` under `set -e`.
- Found during pre-commit testing of the new task-queue feature: ran `autopilot-queue list` against a fixture queue where every entry was done/on-hold/stuck, and it exited 2 instead of printing the expected "Nothing runnable" line.
- Neither this feature nor the bug has shipped yet — caught in manual end-to-end testing before commit, not a production incident.

## Findings

- **2026-07-07:** Root cause confirmed via `bash -x` trace: `cmd_next`'s `exit 2` unwinds the whole `$(...)` subshell before the inner `|| true` can run. Fix is to move the guard outside the substitution: `next_tf=$(cmd_next 2>/dev/null) || true`.

## Resolution

- **2026-07-07:** Fixed in `autopilot-queue` — commit `d951ab4`.
