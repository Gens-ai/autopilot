# Queue Mode: How the Task Queue Actually Runs

Bare `autopilot` (no task file, no subcommand) doesn't ask you what to run —
it drains a committed, ordered list of task files one at a time, each to full
completion, until nothing runnable is left. This is the mechanics behind that:
the queue file format, the `autopilot-queue` subcommand, the drain loop in
`run.sh`, and the failure modes discovered (and fixed) while dogfooding it.

> For the day-to-day command reference, see the [Task Queue Mode](../README.md#task-queue-mode)
> section of the README. This doc is the deep dive.

## The core design decision: status is derived, never stored

The queue file (`docs/autopilot/queue.json`) holds **ordering and intent
only** — which task files, in what order, whether one is held, a free-form
note. It never stores whether an entry is done, in-progress, or stuck. That
is computed on every read from the task file's own `requirements[]` array:

```
runnable = requirements where passes != true and stuck != true and invalidTest != true

runnable > 0, nothing passed/stuck/invalid yet → queued
runnable > 0, some passed/stuck/invalid        → in-progress
runnable == 0, some stuck                      → stuck
runnable == 0, none stuck                      → done
```

(`hold: true` short-circuits to `on-hold`; a missing file is `missing`; a
task file that isn't valid JSON with a `requirements` array is `invalid`.)

This is deliberate, not incidental: a queue that duplicates status invites
drift the moment the two sources disagree — exactly the class of bug that
made [ISSUE-004](issues/ISSUE-004-committed-taskfile-vanishes-after-branch-return.md)
possible (see below). Because status is always recomputed, `autopilot queue
list` can never lie about an entry's real progress; the worst case is it
briefly can't *find* the task file.

## Components

| Piece | Where | Role |
|-------|-------|------|
| `autopilot-queue` | symlinked to `~/.local/bin/autopilot-queue` | Owns all queue read/write logic: `list`, `add`, `rm`, `hold`/`unhold`, `move`, `next`, `stamp`. Everything else shells out to it. |
| `run.sh` (queue mode) | `~/.local/bin/autopilot`, no args | The drain loop: repeatedly asks `autopilot-queue next` for the next runnable entry and runs a full task-mode `run.sh` on it as a child process. |
| `docs/autopilot/queue.json` | project repo, committed | The queue itself: ordering + intent, validated by `queue.schema.json`. |
| `/tasks` | `commands/tasks.md` | Auto-enqueues the task file it just generated (`autopilot queue add <file>`), skipped in `--refresh` mode or if the CLI isn't installed. |

## `autopilot-queue` command reference

```
autopilot queue [list]                            Show the queue with derived status
autopilot queue add <taskfile.json> [--front] [--notes "text"]
autopilot queue rm <taskfile.json|N>               Remove entry (N = 1-based position)
autopilot queue hold <taskfile.json|N>             Keep entry, skip it when draining
autopilot queue unhold <taskfile.json|N>
autopilot queue move <taskfile.json|N> <position>
autopilot queue next                               Print the next runnable task file path
```

Notes on specific commands:

- **`add`** validates the file exists and has a `requirements` array before
  queuing it, and is idempotent — adding an already-queued file reports its
  existing position instead of duplicating it. `--front` inserts at position
  1 instead of appending.
- **`hold`/`unhold`** don't remove the entry or lose its place in the
  ordering; they just make the drain loop's `next` skip over it. Use this for
  "queued but blocked on something external" (the `examples/queue.json`
  billing-webhooks entry — held with a note about waiting on Stripe sandbox
  credentials — is exactly this case).
- **`move`** re-splices the entry to a new 1-based position, clamped to the
  queue's bounds.
- **`next`** is the machine-readable primitive everything else is built on:
  it prints the first entry whose derived status is `queued` or
  `in-progress`, skipping (and warning on stderr about) `missing`/`invalid`
  entries, and exits `2` with nothing on stdout when nothing is runnable.
  `run.sh`'s drain loop calls it every iteration; that's the entire
  "what do I run next" decision.
- **`stamp start|finish <taskfile>`** is internal — `run.sh` calls it to
  record `startedAt`/`completedAt` timestamps. These are informational only
  (shown nowhere but useful for auditing queue history); they play no role in
  status derivation.

Override the queue file location with `AUTOPILOT_QUEUE_FILE` (both
`autopilot-queue` and `run.sh` honor it) — useful for a monorepo with more
than one independent queue.

## The drain loop (`run.sh`, queue mode), step by step

1. **Print the queue** (`autopilot-queue list`) so you can see what's about
   to run before it does.
2. **Remember the starting branch.** Task mode checks out (or creates) a
   feature branch per task file; without returning to the start branch
   between entries, each feature would stack on top of the previous one's
   branch instead of forking from the same base.
3. **Loop:**
   1. Ask `autopilot-queue next` for the next runnable entry. Nothing
      runnable → print "Queue drained" and exit 0.
   2. Stamp `start`, snapshot `git status --porcelain` (excluding the queue
      file, `.autopilot/`, and this entry's own directory) as the **before**
      state.
   3. Spawn a full task-mode `run.sh <taskfile> --batch N --delay N
      [--model M]` as a child process (same locking, monitoring, and
      analytics as running that file directly) and wait for it, forwarding
      SIGUSR1/Ctrl+C to the child if a stop is requested mid-entry.
   4. **Ground-truth check:** re-read the task file. If any requirement is
      still runnable, the child was stopped or died mid-way — do **not**
      advance the queue on top of a half-finished entry. Stop the drain.
   5. Otherwise stamp `finish`. If some requirements ended `stuck`, say so
      (the entry is flagged for attention) but still advance — a stuck entry
      does not block the rest of the queue.
   6. Snapshot `git status --porcelain` again (same exclusions) as the
      **after** state and diff it against **before** (`comm -13`). Only
      paths that became dirty *during this entry* count as new dirt.
      - New dirt present → stop the drain (don't build the next entry on top
        of uncommitted changes).
      - Otherwise, if the child left a different branch checked out, `git
        checkout -q <start-branch>` — and immediately re-checkout this
        entry's directory from the branch just left
        (`git checkout -q <feature-branch> -- <entry-dir>`), a no-op unless
        that checkout actually deleted tracked files, which happens when the
        entry's own task/notes JSON got committed on the feature branch (see
        ISSUE-004 below).
   7. Sleep `--delay` seconds, repeat.
4. **Print the queue again** on exit, so the final state is visible whether
   the drain finished cleanly or stopped early.

## Stopping and resuming

`/autopilot stop` (or Ctrl+C on the wrapper's own terminal) works the same as
task mode, with one extra layer: queue mode runs **two** wrappers at once —
the queue parent (`.autopilot/queue.pid`) and a task-mode child for the
current entry (`run.pid` next to that entry's task file). Signaling either
one stops the whole drain gracefully:

- Signal the **parent** → it forwards SIGUSR1 to the active child, which
  finishes its current session and exits; the parent then sees a runnable
  requirement remaining and halts instead of advancing.
- Signal only the **child** → same outcome, from the other direction.

Either way, nothing is lost: the queue file's ordering is untouched, the
in-flight task file's `passes`/`stuck` flags are ground truth as of the last
commit, and the next `autopilot` invocation calls `autopilot-queue next`
fresh — which resumes at the same entry if it's still `in-progress`, or
starts the entry after it if it finished.

## Failure modes and their guards

These were all found by dogfooding queue mode end-to-end against real Claude
sessions, not by inspection — each has a full writeup in `docs/issues/`.

| Failure | Guard | Issue |
|---------|-------|-------|
| `autopilot queue list` crashed instead of printing "Nothing runnable" when every entry was done/stuck/held | `cmd_next`'s `exit 2` unwinds a `$(...)` subshell before an internal `\|\| true` can run; the guard must sit outside the substitution | [ISSUE-001](issues/ISSUE-001-queue-list-exit-under-set-e.md) |
| Drain halted after every single entry, mistaking autopilot's own bookkeeping (queue stamps, notes/analytics files) for leftover feature work | `git status` scoped to exclude the queue file, `.autopilot/`, and the entry's own directory | [ISSUE-002](issues/ISSUE-002-queue-drain-false-dirty-tree.md) |
| Drain still halted on *pre-existing* untracked cruft unrelated to autopilot (a stray log, `.env.local`, editor droppings) — a static point-in-time check can't tell "was already there" from "just appeared" | Before/after `git status` snapshot per entry, diffed with `comm -13`; only genuinely new dirt blocks the drain | [ISSUE-003](issues/ISSUE-003-queue-dirty-check-blocks-on-preexisting-cruft.md) |
| A fully-finished entry (all requirements passed, real commits made) showed as `missing` afterward because its own task JSON got swept into a feature-branch commit and the branch-return `git checkout` correctly deleted it (tracked on the branch being left, absent from the branch being returned to) | Two-part fix: (1) `commands/autopilot.md` now stages only the specific source/test files per requirement commit, never `git add -A`/`.`, and never the task/notes/analytics files; (2) `run.sh`'s branch-return step restores the entry directory from the feature branch as a defense-in-depth safety net regardless of what actually got committed | [ISSUE-004](issues/ISSUE-004-committed-taskfile-vanishes-after-branch-return.md) |
| Child run stopped or died with runnable requirements still left | Drain checks remaining-runnable count before advancing; halts instead of starting the next entry on top of a half-done one | — |

The practical upshot of ISSUE-002/003 together: **only changes introduced by
the entry that just ran can block the drain.** Ordinary repo cruft that
predates the run, and autopilot's own bookkeeping, are both invisible to the
check. The practical upshot of ISSUE-004: even if a session violates the
commit-scoping convention and sweeps the task file into a feature-branch
commit, the queue's view of that entry self-heals on the very next
branch-return — you should not need to manually `git checkout <branch> --
<entry-dir>` yourself, but that's exactly what to do if you ever see a
finished entry reported as `missing` from an older run.

## Worked example

```bash
# /tasks auto-queues each file as it's generated
/tasks docs/autopilot/user-auth/user-auth.md      # → queued at position 1
/tasks docs/autopilot/billing/billing.md          # → queued at position 2

# Something's blocking billing — park it without losing its place
autopilot queue hold docs/autopilot/billing/billing.json --notes "waiting on Stripe sandbox creds"
autopilot queue add docs/autopilot/password-reset/password-reset.json --front

autopilot queue
#   1  queued        0/5  docs/autopilot/password-reset/password-reset.json
#   2  queued        0/7  docs/autopilot/user-auth/user-auth.json
#   3  on-hold       0/4  docs/autopilot/billing/billing.json  (waiting on Stripe sandbox creds)
#   Next up: docs/autopilot/password-reset/password-reset.json  (run 'autopilot' to start)

# Drain overnight
autopilot --batch 2 --model sonnet

# ... some hours later, from any session in the project
/autopilot stop
```

`autopilot queue` afterward shows exactly which entries finished, which (if
any) are `stuck` and need a human look, and which are still `queued` because
the drain stopped before reaching them.
