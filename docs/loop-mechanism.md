# The Loop Mechanism: How Autopilot Actually Runs

Autopilot is two nested loops. Understanding both — and the files they use to
coordinate — explains almost every behavior you'll observe, and almost every
failure mode.

```
┌─ OUTER LOOP — run.sh (bash wrapper, "autopilot" on your PATH) ────────────┐
│  One iteration = one fresh Claude session = (usually) one requirement.    │
│  Holds the run.pid lock. Monitors the task JSON from outside.             │
│                                                                           │
│   ┌─ INNER LOOP — Stop hook (the "Ralph loop") ───────────────────────┐   │
│   │  One iteration = one Claude turn within a session.                │   │
│   │  When Claude stops mid-requirement, the hook blocks the exit      │   │
│   │  and re-feeds the task prompt until the completion promise        │   │
│   │  appears or max_iterations is reached.                            │   │
│   └───────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

You can run either loop alone: `/autopilot tasks.json` inside a session uses
only the inner loop (context accumulates); `autopilot tasks.json` from a
terminal uses both (fresh context per requirement, hook-driven persistence
within each session).

## Components

| Piece | Where | Role |
|-------|-------|------|
| `run.sh` | symlinked to `~/.local/bin/autopilot` | Outer loop: spawns/kills Claude sessions, monitors progress, owns the lock |
| `commands/autopilot.md` | symlinked into `~/.claude/commands/` | The `/autopilot` slash command: pre-flight checks, mode dispatch, writes `loop-state.md`, executes the TDD cycle |
| `hooks/stop-hook.sh` | symlinked to `~/.claude/hooks/autopilot-stop-hook.sh` | Inner loop: intercepts session stop events |
| Stop hook registration | `~/.claude/settings.json` → `hooks.Stop` | What makes Claude Code actually call the hook (see below) |

## Coordination files

All paths are relative to the project root. **STATE_DIR** is the task file's
directory when launched via `run.sh` (passed as `--state-dir`), else
`$AUTOPILOT_STATE_DIR`, else `.autopilot/`.

| File | Written by | Read by | Meaning |
|------|-----------|---------|---------|
| `<taskfile-dir>/run.pid` | `run.sh` at startup | `run.sh` (startup lock check), `/autopilot` §0b (collision check), `/autopilot stop` | "A wrapper loop owns this task file." Contains the wrapper's PID. Removed by the EXIT trap. |
| `$STATE_DIR/loop-state.md` | `/autopilot` (session setup); iteration counter rewritten by the stop hook | stop hook | "An inner loop is active *in this directory*." YAML frontmatter (`iteration`, `max_iterations`, `completion_promise`, `analytics_file`, `task_file`) + the prompt to re-feed. |
| `$STATE_DIR/stop-signal` | the Claude session when ALL requirements are done | `run.sh` (checked every 2s) | "Exit the outer loop now." |
| `<taskfile>` (the task JSON) | the Claude session (`passes`/`stuck`/`invalidTest` flags) | `run.sh` (progress monitoring), next sessions | Ground truth for progress. |
| `<taskfile-dir>/analytics/*.json` | `/autopilot` + hooks | `/autopilot analyze` | Session metrics. |

Note the asymmetry: `run.pid` lives next to the **task file** (wherever that
is — `docs/autopilot/<feature>/`, `docs/tasks/prds/`, anywhere), while
`loop-state.md` lives in **STATE_DIR**, which is the same directory only when
run.sh passes `--state-dir`. A `loop-state.md` in `.autopilot/` comes from
running `/autopilot` directly inside a session.

## The outer loop (run.sh), step by step

1. **Validate** — task file exists, is JSON, has a `requirements` array.
2. **Acquire the lock** — if `<taskfile-dir>/run.pid` exists and its PID is
   alive, refuse to start ("Another autopilot instance is running"). If the
   PID is dead, remove the stale file. Then write our own PID and install an
   EXIT trap that kills the current Claude session tree, sweeps daemonized
   stragglers, and removes the PID file.
3. **Spawn a session** —
   ```
   claude --allowedTools ... -- "/autopilot <taskfile> --batch N --wrapper-pid $$ --state-dir <taskfile-dir>"
   ```
   The two trailing flags are internal self-identification (see next section).
4. **Monitor from outside** (every 2 seconds), because the wrapper cannot see
   inside the session — it watches the task JSON instead:
   - `stop-signal` file appeared → kill session, exit: everything is done.
   - completed+stuck count advanced by ≥ batch size → kill session, loop:
     fresh context for the next requirement.
   - some progress, then 30s idle → kill session, loop (session finished its
     batch but didn't exit).
   - zero progress for 30 minutes → kill session, loop (assume wedged).
   - SIGUSR1 / Ctrl+C received → kill session, clean up, exit.
5. **Repeat** until no workable requirements remain (`passes`, `stuck`, or
   `invalidTest` on every one).

"Kill session" is `kill_session()`: it collects the session's descendant PIDs
*first* (children reparent to init once the parent dies), SIGTERMs the tree,
waits up to 5s, then SIGKILLs survivors.

## Self-identification: `--wrapper-pid` and `--state-dir`

The `/autopilot` pre-flight (§0b of `commands/autopilot.md`) checks for a
`run.pid` next to the task file so an *interactive* `/autopilot` run can
detect that a wrapper loop already owns the file and refuse to compete with
it. But when the session was **spawned by that very wrapper**, the lock it
finds is its own parent — which once caused every spawned session to refuse
to work, reporting its own wrapper as "another autopilot instance" while the
wrapper dutifully restarted it every 30 minutes, forever.

So the wrapper identifies itself, in argv rather than environment variables
(env vars do not reliably propagate into the session's tool shells):

- `--wrapper-pid <N>` — the wrapper's own PID. §0b rule: if the PID inside
  `run.pid` equals this value, the lock is your own parent — **not** a
  collision; proceed. A *different* live PID is a real collision: stop and
  ask the user. (`AUTOPILOT_WRAPPER_PID` is also exported as a fallback.)
- `--state-dir <dir>` — where to write `loop-state.md` and `stop-signal`.
  Without it, sessions fall back to `.autopilot/` while the wrapper watches
  the task-file directory, and the two never see each other's signals.

## The inner loop (Stop hook), step by step

Claude Code runs the hook every time a session is about to stop (i.e., a turn
ends). Input arrives as JSON on stdin (including `transcript_path`); the
hook's stdout JSON decides what happens:

```
loop-state.md missing?             → {}                      (allow exit — not in a loop)
loop-state.md untouched > 24h?     → delete it, {}           (stale-state guard)
frontmatter unparseable?           → delete it, {}           (fail open)
iteration ≥ max_iterations?        → delete it, {}, SIGTERM  (give up)
last assistant message contains
  <promise>COMPLETE</promise>?     → delete it, {}, SIGTERM  (genuinely done)
otherwise                          → increment iteration, re-feed:
                                     {"decision": "block", "reason": "<the prompt>", ...}
```

Details that matter:

- **The completion promise** is read from the session transcript (last
  assistant message), compared literally after whitespace normalization. This
  is why the task prompt insists: only output `<promise>COMPLETE</promise>`
  when truly finished — it is the only honest way out of the loop before
  max_iterations.
- **Allow = `{}`.** For Stop hooks, omitting `decision` means "allow";
  `"decision": "allow"` is not a valid value.
- **Forced exit is SIGTERM to `$PPID`** (the hook runs as a child of the
  Claude process), sent from a detached subshell after a 0.5s delay so the
  hook can return cleanly first. Under run.sh this ends the session and the
  outer loop takes over; in an interactive session it ends your session —
  which is what "the loop is complete" means.
- **The stale-state guard** exists because an active loop rewrites
  `loop-state.md` on every iteration (and run.sh deletes it whenever it kills
  a session). A copy untouched for >24h is a leftover from a dead run; without
  the guard, the next session you happen to open in that directory would be
  pulled into a zombie autopilot loop on its first stop.

### Registration — the part that must be right

Claude Code only runs hooks declared in **`settings.json`** (user-level:
`~/.claude/settings.json`). `install.sh` registers:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/autopilot-stop-hook.sh" }
        ]
      }
    ]
  }
}
```

Two historical gotchas, both fixed in `install.sh` but worth knowing:

- `~/.claude/hooks.json` is **not** a Claude Code config file. Early installs
  wrote the registration there, so the hook never fired: `iteration` never
  advanced past 1, completion never cleaned up state files, and sessions that
  stopped mid-requirement just idled until the outer loop's timeout killed
  them. If autopilot "works but seems to waste 30-minute stretches," check
  the registration first.
- Hook config is read at session startup. After installing or changing it,
  **restart Claude Code sessions** to pick it up.

The hook is global to all projects, but it no-ops (`{}`) unless a fresh
`loop-state.md` exists in the session's STATE_DIR, so it is inert outside
autopilot runs.

## Stopping things

| You want to | Do this | Mechanism |
|-------------|---------|-----------|
| Stop the wrapper gracefully | `/autopilot stop` (any session in the project) | Finds `run.pid`/`command.pid` files repo-wide, sends SIGUSR1; run.sh finishes the current check cycle and exits via its cleanup trap |
| Stop the wrapper from its own terminal | Ctrl+C | SIGINT sets the same stop flag |
| Cancel an inner loop without touching the wrapper | `/autopilot cancel` | Deletes `$STATE_DIR/loop-state.md`; the hook allows exit on the next stop |
| Everything is done (automatic) | — | The session writes `$STATE_DIR/stop-signal`; run.sh sees it within 2s and exits |

## Failure modes and their guards

| Failure | Guard |
|---------|-------|
| Two wrappers on the same task file | `run.pid` lock check at startup |
| Wrapper killed hard (SIGKILL, SIGHUP) leaves a stale lock | Dead-PID check at next startup removes it; `/autopilot stop` also cleans stale PID files |
| Session detects its own wrapper as a foreign instance | `--wrapper-pid` own-wrapper exemption in §0b |
| Session and wrapper disagree on where state files live | `--state-dir` passed in argv; env-var resolution is only a fallback |
| Session wedges (no output, no progress) | Outer loop kills it after 30 min without task-JSON progress |
| Session lies about completion / stops early | Hook re-feeds the prompt until the `<promise>` appears or max_iterations |
| Infinite inner loop | `max_iterations` in loop-state frontmatter; hook SIGTERMs at the cap |
| Zombie `loop-state.md` hijacks unrelated sessions | 24h stale-state guard in the hook |
| Orphaned MCP/daemon child processes | `cleanup_stale_processes` sweep after every session and on exit; `autopilot-cleanup` manually |

## Life of one requirement (both loops together)

```
run.sh: lock → spawn claude "/autopilot tasks.json --batch 1 --wrapper-pid 12345 --state-dir docs/tasks/prds"
  session: pre-flight (config, §0b: run.pid == 12345 == own wrapper → proceed)
  session: writes docs/tasks/prds/loop-state.md (iteration 1)
  session: RED — failing test, commit
  session: ...turn ends (context exhausted mid-requirement)
    stop hook: promise? no. iteration 1 < 15 → block, re-feed prompt (iteration 2)
  session: GREEN — implementation, tests pass, commit
  session: REFACTOR — simplify, feedback loops green, commit; marks passes: true
  session: outputs <promise>COMPLETE</promise>
    stop hook: promise matches → rm loop-state.md, SIGTERM session
run.sh: (in parallel, every 2s) sees passes flipped in tasks.json → batch complete
run.sh: kill_session, rm loop-state.md, print progress → next fresh session
```
