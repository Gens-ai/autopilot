# Vision

> You describe the feature. Autopilot plans it, builds it test-first, and leaves a
> reviewable branch — while you sleep.

Autopilot exists to make **unattended, trustworthy software development** a normal
thing to do with Claude Code: not a demo, not a gamble, but a workflow you run
overnight and review over coffee.

## The problem

Coding agents are already capable of implementing well-specified features. What they
lack is an **operating discipline** for working alone:

- Left unsupervised, an agent drifts — it re-explores what it already learned,
  re-implements what already exists, and burns its context window on its own history.
- Its memory is its context, and context degrades. After enough iterations the
  session that started sharp finishes sloppy.
- Without hard feedback loops, "done" means "the model believes it's done" — which is
  worth exactly nothing at 3 a.m. with nobody watching.
- When it hits a wall, it doesn't stop. It retries the same failing thing thirty
  times, at full token price.

None of these are model problems that will simply age away. They are **process
problems**, and processes are what you can build.

## The thesis

Autopilot's core bet is that autonomous development works when you split the work at
the right seam:

**Human judgment up front, machine execution after, ground truth in between.**

- **Up front:** `/prd` interviews you like a senior PM until the feature is fully
  specified — no "open questions" survive into the document. `/tasks` studies the
  codebase before planning, so every requirement knows whether it's a `create`,
  `extend`, `modify`, or `already-done`. This is where the expensive model and the
  human attention belong. You review the plan, not the keystrokes.
- **After:** the autopilot loop executes requirements one at a time through a strict
  Red → Green → Refactor cycle, gated by the project's own typecheck/test/lint
  commands before every commit. The machine doesn't get to decide what "done" means;
  the test suite does.
- **In between:** every piece of state that matters lives in files on disk — the task
  JSON, the notes file, git history — never in the model's head. Any session can die
  at any moment and the next one resumes exactly where it left off.

## Design principles

These aren't aspirations; each one was earned by watching the system fail without it
(the CHANGELOG and `docs/issues/` are the receipts).

**1. Ground truth lives in files, not in context.**
Progress is the `passes`/`stuck`/`invalidTest` flags in the task JSON plus git
history. Notes files are for continuity, not authority. A session is disposable;
the state is not.

**2. Derive state — never store it twice.**
The task queue holds only ordering and intent; every entry's status is recomputed
from its task file on every read, so `autopilot queue` *cannot* lie about progress.
Anywhere two copies of the same fact can exist, they will eventually disagree —
so don't allow two copies.

**3. Fresh context beats long context.**
One requirement per session is the default, not the fallback. Context is a
consumable: spend it on the current requirement, then throw it away. The Ralph
Wiggum insight — the loop is more reliable than the memory — is the foundation
everything else stands on.

**4. Tests are the arbiter of done.**
Red must actually fail (a test that passes before implementation is flagged
`invalidTest`, not celebrated). Green and Refactor run the full suite as regression
gates. Nothing gets committed on a failing feedback loop, ever. Acceptance criteria
written at planning time become the test cases — "done" is defined before the first
line of implementation.

**5. Prefer blocked to wrong.**
Three consecutive failures → `stuck: true` with a `blockedReason`, move on. The same
error repeating → thrashing detection aborts immediately. No TODOs, no stubs, no
"will fix later" in committed code. A stuck requirement waiting for a human costs
nothing; a plausible-but-wrong implementation costs a debugging session.

**6. Infrastructure for bookkeeping, prompts for judgment.**
Every time the LLM was *instructed* to do accounting, it eventually didn't (analytics
files stayed empty for weeks until a shell script took over). Iteration counts,
requirement status, file tracking — all derived by scripts from git and JSON. The
model's attention is reserved for the only thing that needs it: writing the code.

**7. Spend tokens like money.**
Low iteration defaults, notes-first orientation, scoped test runs in the Red phase,
cheap models for TDD grunt work and expensive ones for planning. The metric that
matters is not "can it finish" but **cost per shipped requirement** — and analytics
plus `/autopilot analyze` exist to push that number down run over run.

**8. Plain substrate, no magic.**
Bash, jq, markdown, JSON, git. No daemon, no service, no framework. Every
coordination file (`run.pid`, `loop-state.md`, `stop-signal`, the queue) is
human-readable and lives in the repo or next to the task file. When something goes
wrong at 3 a.m., you can diagnose it with `cat` — and `autopilot-status` does exactly
that for you, read-only.

**9. Trust is scoped, and safety is structural.**
Work lands on a feature branch named after the task file — `main` stays clean until
you merge. Commit authorization is explicit and scoped to the TDD protocol; nothing
ever pushes. Sandbox mode is the recommended default. Autonomy is granted per-run,
per-scope — never assumed.

**10. Dogfood everything; every failure becomes a guard.**
Queue mode's worst bugs (drift, false-dirty halts, a finished task file vanishing
from its own queue) were found by running autopilot on real work, filed as issues,
fixed, and documented. The project improves the same way it asks its users' projects
to improve: through feedback loops with teeth.

## What autopilot is not

- **Not an agent framework.** It's a workflow with opinions, built from prompts,
  hooks, and shell. If you want a platform, this isn't it — on purpose.
- **Not a replacement for review.** The output is a reviewable branch with a legible
  commit trail, not auto-merged code. Autopilot's job is to make the morning review
  a skim instead of a forensic audit.
- **Not a UI product.** No dashboard, no web app. The terminal, git log, and a few
  JSON files are the interface.
- **Not magic.** A vague PRD produces a confused branch. The quality ceiling is set
  at planning time — which is exactly why planning is the human's job.

## Where it's going

The trajectory so far — single task file → fresh-session wrapper → analytics and
thrashing detection → built-in loop → command loops → story auditing → status
introspection → the task queue — points at one destination:

**A self-managing development pipeline you feed with intent.**

You maintain a queue of specified features. The system drains it: plans against the
live codebase, builds test-first on isolated branches, flags what it can't solve,
audits what it shipped, and reports. Your job collapses to the two ends that
genuinely need a human: deciding *what* to build, and judging *whether it's right*.

Near term, that means hardening what exists:

- **Queue mode as the default way to run autopilot** — battle-tested unattended
  drains, better halt/resume ergonomics, richer `autopilot-status` over long runs.
- **Parallel agents, phase 2.** Per-feature state isolation and the commit mutex
  exist; the next step is letting the queue drain multiple independent entries
  concurrently instead of strictly in order.
- **Analytics that close their own loop** — `/autopilot analyze` suggestions feeding
  back into `AGENTS.md` and `autopilot.json` with less manual ceremony, so every run
  makes the next one cheaper.

Further out, ideas already on the bench (see `docs/brainstorms/`):

- **Subjective backpressure.** LLM-as-judge feedback loops for the criteria tests
  can't express — naming quality, doc clarity, UI consistency — as a fourth gate
  beside typecheck/test/lint.
- **Living plans.** A regenerable, disposable execution plan alongside the rigid task
  JSON: JSON stays the source of truth for *status*, markdown becomes the cheap,
  re-derivable artifact for *tactics* — delete and regenerate when it goes stale.
- **Specs as a first-class input.** A `specs/` directory organized by topic of
  concern, with gap analysis run against the whole set — planning against what the
  system *should be*, not just per-feature deltas.
- **Closing the verification loop.** `test-stories` already audits existing features
  against user stories in a browser; the end state is a pipeline where "built" is
  always followed by "verified in use," automatically.

## How we'll know it's working

- An overnight queue drain completes without a human unsticking anything — and when
  something *is* stuck, the `blockedReason` alone is enough to act on.
- Tokens per shipped requirement trend down across runs on the same project, because
  the analytics loop is actually feeding learnings back.
- The morning review is boring: read the PRD once, skim the commits, run the app,
  merge.
- The trust radius grows — from "watch the first few iterations" to "check in
  tomorrow" — without a single weakening of the guardrails that made that trust
  rational.

---

*Autopilot builds on the [Ralph Wiggum technique](https://ghuntley.com/ralph/) and
the community listed in the README. The vision is the same one Ralph pointed at —
the loop outlives the context — carried to its practical conclusion: a discipline,
not a trick.*
