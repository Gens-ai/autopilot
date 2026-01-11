# Autopilot Improvements Inspired by Ralph Playbook

> Analysis Date: 2026-01-10
>
> This document captures improvement ideas for the Autopilot project based on patterns, approaches, and examples found in Geoffrey Huntley's Ralph Playbook.

---

## Implemented

The following suggestions have been implemented by enhancing `/tasks` with codebase analysis and gap analysis phases:

| # | Suggestion | Implementation |
|---|------------|----------------|
| 1 | Separate Plan and Build Prompts | **Alternative approach:** Integrated planning into `/tasks` instead of separate prompts. `/tasks` now performs codebase analysis before generating tasks. |
| 4 | Gap Analysis Before Implementation | `/tasks` Phase 0-1 now searches codebase, identifies existing code, and categorizes each requirement as `create`/`extend`/`modify`/`already-done`. |
| 5 | "Don't Assume Not Implemented" | Built into `/tasks` Phase 1 with explicit "Critical Rule: Don't assume something isn't implemented. Always search first." |
| 6 | Guardrail Numbering Convention | `autopilot.md` restructured with Phase 0 (pre-flight), Phase 1 (execution), Phase 99999+ (critical guardrails). |
| 19 | Graceful Plan Regeneration | `/tasks --refresh` flag re-analyzes incomplete requirements while preserving completed ones. |
| 23 | Explicit Phase Numbering | `/tasks` and `autopilot.md` now use explicit phase numbering (0a, 0b, 0c for orientation; 99999+ for guardrails). |
| 24 | Single Source of Truth | Added as guardrail 999999999 in `autopilot.md` and in `AGENTS.md` Guardrails section. |
| 25 | No Placeholders | Added as guardrail 99999999 in `autopilot.md` and in `AGENTS.md` Guardrails section. |

**New files created:**
- `tasks.schema.json` - JSON Schema for task files with `codeAnalysis` field
- Updated `commands/tasks.md` - Enhanced with codebase analysis phases
- Updated `examples/tasks-user-auth.json` - Example with `codeAnalysis` populated

---

## 1. ~~Separate Plan and Build Prompts~~ (Implemented Differently)

**Status:** Implemented via enhanced `/tasks` command.

**Original idea:** Split autopilot.md into PROMPT_plan.md and PROMPT_build.md.

**What we did instead:** Integrated gap analysis and codebase exploration into `/tasks` itself. This keeps the existing command structure while adding Ralph's planning intelligence at task generation time.

**Benefits of our approach:**
- No new commands to learn
- Tasks are code-aware from the start
- `--refresh` provides regeneration capability
- Simpler architecture than separate plan/build modes

---

## 2. Regenerable Implementation Plan Pattern

**Description:** Introduce an `IMPLEMENTATION_PLAN.md` file as a living, disposable artifact that can be regenerated cheaply.

**Purpose:** Ralph emphasizes that the plan is disposable - when it goes stale or Ralph goes off-track, simply delete and regenerate. This is more flexible than the current JSON task file approach.

**Details:**
- Current autopilot uses rigid JSON with `passes`, `stuck`, `tdd` phases
- Ralph's plan is freeform markdown that Ralph itself structures
- Plan regeneration costs only one loop iteration
- Criteria for regeneration:
  - Ralph goes off track
  - Plan doesn't match current state
  - Too much clutter from completed items
  - Significant spec changes
- JSON stays as source of truth for requirements; plan becomes tactical execution artifact

**Implementation:**
- Add `/autopilot replan` or `/autopilot tasks.json --replan` mode
- Generate `docs/tasks/prds/*-plan.md` alongside existing files
- Plan can be more detailed than JSON requirements (subtasks, discoveries, blockers)
- Consider hybrid: JSON for tracking status, markdown plan for execution guidance

---

## 3. Specs Directory Organization

**Description:** Adopt a dedicated `specs/` directory pattern with one file per topic of concern.

**Purpose:** Better organization of requirements. Each spec addresses one coherent topic. Enables easier maintenance and targeted updates.

**Details:**
- Ralph organizes specs by topic of concern, not by feature
- Each spec file passes the "one sentence without 'and'" test
- Topics map to distinct areas: authentication, data modeling, UI components, integrations
- Easier to update individual topics without touching entire PRD
- Better for monorepo/multi-package projects where topics cross packages

**Implementation:**
- Add `specs/` as alternative input to `/autopilot`
- `/autopilot specs/` runs gap analysis across all spec files
- `/tasks` could output to `specs/` with one JSON per spec
- Consider spec templates for common patterns (API endpoint, UI component, background job)

---

## 4. ~~Gap Analysis Before Implementation~~ (Implemented)

**Status:** Implemented in `/tasks` Phase 0-1.

See "Implemented" section above. The `/tasks` command now:
- Phase 0b: Searches for related code using parallel subagents
- Phase 0c: Studies discovered files for patterns and partial implementations
- Phase 1: Performs gap analysis, categorizing each requirement's approach
- Populates `codeAnalysis.approach` as `create`/`extend`/`modify`/`already-done`
- Pre-populates `targetFiles.modify` and `targetFiles.create` with specific paths

---

## 5. ~~"Don't Assume Not Implemented" Guardrail~~ (Implemented)

**Status:** Implemented in `/tasks` Phase 1.

See "Implemented" section above. The `/tasks` command now includes:
- Explicit instruction: "Critical Rule: Don't assume something isn't implemented. Always search first."
- Codebase search before generating each requirement
- `codeAnalysis.existingFiles` populated with discovered related code
- TDD descriptions reference specific existing files and patterns

---

## 6. ~~Guardrail Numbering Convention~~ (Implemented)

**Status:** Implemented in `autopilot.md`.

`autopilot.md` now has:
- **Phase 0**: Pre-flight (0a. Configuration Check, 0b. Argument Parsing, 0c. Mode Detection)
- **Phase 1**: Mode Execution
- **Phase 99999+**: Critical Guardrails with escalating priority:
  - 99999: Feedback Loops Before Commits
  - 999999: Never Commit on Failure
  - 9999999: Search Before Implementing
  - 99999999: No Placeholders or TODOs
  - 999999999: Single Source of Truth

---

## 7. Subagent Parallelization Strategy

**Description:** Explicitly document when to use parallel subagents vs sequential execution.

**Purpose:** Ralph uses up to 500 parallel subagents for reading/searching but limits to 1 for build/tests. This optimizes context usage while maintaining backpressure.

**Details:**
- Parallel subagents for: file reading, grep searches, spec analysis, gap analysis
- Sequential (single) subagent for: tests, builds, commits
- Reasoning: backpressure requires single point of control
- Parallel reads don't accumulate context in main agent
- Build results must feed back to main agent for decisions

**Implementation:**
- Add guidance to AGENTS.md: "Use parallel subagents for exploration, single subagent for execution"
- Update autopilot.md to explicitly spawn parallel subagents during orientation phase
- Document expected subagent counts per phase

---

## 8. Ultrathink Keyword Pattern

**Description:** Add "Ultrathink" as a trigger keyword for deep reasoning mode on complex decisions.

**Purpose:** Ralph uses this keyword to signal that extra careful reasoning is needed. Triggers extended thinking/analysis.

**Details:**
- Placed before complex decisions or architectural choices
- Signals "pause and think deeply before proceeding"
- Useful for: task prioritization, architectural decisions, stuck detection, refactoring scope
- Not for routine operations (too expensive)

**Implementation:**
- Add to autopilot.md at key decision points: "Ultrathink: What is the highest-priority task?"
- Document in AGENTS.md as recognized trigger
- Consider adding `--ultrathink` flag for verbose reasoning mode

---

## 9. LLM-as-Judge for Subjective Criteria

**Description:** Add pattern for non-deterministic backpressure using LLM review for subjective quality checks.

**Purpose:** Some criteria (UX polish, tone, aesthetic quality) can't be validated with traditional tests. LLM-as-judge provides automated subjective feedback.

**Details:**
- Ralph creates `src/lib/llm-review.ts` fixture for LLM-based tests
- Binary pass/fail with optional feedback
- Used for: documentation clarity, UI consistency, code readability, naming quality
- Ralph discovers pattern from test examples and reuses

**Implementation:**
- Add example `llm-review.md` utility to examples/
- Document pattern in AGENTS.md
- Consider adding to feedback loops: `llmReview: { enabled: true, criteria: "..." }`
- Could integrate with existing code-simplifier agent

---

## 10. AskUserQuestion for Planning Interview

**Description:** Use Claude's AskUserQuestion tool during PRD phase to systematically interview the user.

**Purpose:** Ralph recommends using built-in interview capabilities to explore JTBDs, edge cases, and acceptance criteria. More structured than freeform conversation.

**Details:**
- Current `/prd` asks clarifying questions but as text, not using AskUserQuestion tool
- AskUserQuestion provides structured options and multi-select
- Can systematically cover: user personas, acceptance criteria, edge cases, constraints
- Structured responses easier to parse into requirements

**Implementation:**
- Update prd.md to use AskUserQuestion tool for clarification phase
- Create question templates for common domains (auth, CRUD, integrations)
- Structure questions as: high-level goals → user stories → edge cases → constraints

---

## 11. Version Tagging During Implementation

**Description:** Add automatic semantic version tagging (0.0.0 → 0.0.1) during commits.

**Purpose:** Ralph emphasizes version tags for tracking progress and enabling rollback. Each completed requirement increments the patch version.

**Details:**
- Ralph's build prompt includes: "Tag versions (0.0.0 → 0.0.1, etc.)"
- Provides clear progress markers
- Enables rollback to specific requirement completion points
- Works with existing git tag infrastructure

**Implementation:**
- Add `--tag` option to autopilot that creates git tag after each requirement
- Naming convention: `autopilot/feature-name/v0.0.1`
- Consider auto-increment logic based on TDD phase (patch for green, minor for refactor)
- Update rollback mode to use version tags

---

## 12. JTBD Hierarchy Documentation

**Description:** Document the Jobs-to-Be-Done → Topics of Concern → Specs → Tasks hierarchy.

**Purpose:** Ralph provides a clear mental model for decomposing work. This structured approach improves PRD quality.

**Details:**
- **JTBD**: High-level user outcome ("Help designers create mood boards")
- **Topics of Concern**: Distinct aspects ("Image collection", "Color extraction", "Layout")
- **Spec**: Requirements for one topic (one file per topic)
- **Task**: Unit of work from gap analysis

- Each topic passes "one sentence without 'and'" test
- Forces proper decomposition before implementation

**Implementation:**
- Add JTBD section to prd.md template
- Update tasks.md to organize requirements by topic of concern
- Add `topic` field to requirement JSON schema
- Document hierarchy in README and examples

---

## 13. Work Branch Scoping

**Description:** Create branch-specific implementation plans instead of runtime filtering.

**Purpose:** Ralph recommends scoping at plan creation time (deterministic) rather than runtime filtering (probabilistic).

**Details:**
- Create `./run.sh plan-work "user auth with OAuth"` command
- Generates scoped plan for specific work, not full feature
- Each work branch has its own plan file
- Prevents Ralph from wandering into unrelated tasks
- Cleaner git history with focused branches

**Implementation:**
- Add `--scope "description"` flag to `/autopilot`
- Generate branch-specific plan: `docs/tasks/prds/feature-branch-plan.md`
- Filter task JSON to scoped subset before execution
- Support `--branch` flag that creates git branch + scoped plan

---

## 14. Context Budget Documentation

**Description:** Document token budget recommendations and context efficiency strategies.

**Purpose:** Ralph explicitly discusses ~200K token window with ~176K usable and 40-60% "smart zone". This knowledge helps tune iteration sizes.

**Details:**
- Ralph recommends: first ~5,000 tokens for specs
- Tight tasks + 1 task per loop = 100% smart zone utilization
- Use subagents to offload expensive exploration
- Fresh context each iteration clears accumulated garbage
- Markdown more efficient than JSON for certain content

**Implementation:**
- Add "Context Efficiency" section to CLAUDE.md
- Document recommended file sizes for specs, plans, notes
- Add guidance on when to restart session vs continue
- Consider adding context usage estimation to notes file

---

## 15. Enhanced Sandbox Documentation

**Description:** Add comprehensive sandbox environment comparison documentation.

**Purpose:** Ralph includes detailed comparison of E2B, Fly Sprites, Modal, etc. This helps users choose appropriate isolation for their needs.

**Details:**
- Ralph documents: cold start time, session duration, isolation level, best use case
- Recommends E2B for production (pre-built Claude template, 24h sessions)
- Documents Claude Code's `--sandbox` flag relationship
- Security philosophy: "It's not if it gets popped, it's when"

**Implementation:**
- Add `docs/sandbox-environments.md` with comparison table
- Document sandbox configuration in autopilot.json schema
- Add sandbox verification to `/autopilot init`
- Include sandbox recommendations in README

---

## 16. Operational AGENTS.md Discipline

**Description:** Enforce strict operational focus for AGENTS.md - no progress notes or status updates.

**Purpose:** Ralph emphasizes keeping AGENTS.md purely operational (~60 lines). Progress notes belong in plan/notes files.

**Details:**
- Ralph's AGENTS.md sections: Build & Run, Validation, Operational Notes, Codebase Patterns
- NO: changelogs, progress updates, session logs, status reports
- YES: build commands, test commands, discovered patterns, operational gotchas
- Polluted AGENTS.md hurts all future loops (loaded every iteration)

**Implementation:**
- Add template enforcement to AGENTS.md
- Move any non-operational content to notes files
- Add line count check (~60 lines recommended)
- Document separation of concerns: AGENTS.md (operational) vs notes (progress)

---

## 17. Story Map → SLC Release Pattern

**Description:** Add story mapping methodology for release planning.

**Purpose:** Ralph includes JTBD → Story Map → SLC (Simple, Lovable, Complete) pattern for identifying releasable slices.

**Details:**
- Story map: activities as columns, capability depths as rows
- Horizontal slices through map = candidate releases
- SLC criteria filter for viable releases
- Requires `AUDIENCE_JTBD.md` documenting user personas and their jobs
- Enables iterative delivery with complete user value

**Implementation:**
- Add `/prd --story-map` mode for visual release planning
- Generate `AUDIENCE_JTBD.md` template
- Add SLC assessment prompts to task generation
- Consider mermaid diagram output for story maps

---

## 18. Acceptance-Driven Test Requirements

**Description:** Derive test requirements explicitly from acceptance criteria during planning.

**Purpose:** Ralph emphasizes explicit "what to verify" (outcomes) in task descriptions. This prevents placeholder implementations.

**Details:**
- Current TDD phases have descriptions but not explicit verification criteria
- Ralph derives tests from acceptance criteria in specs
- Each task includes: what to implement + how to verify success
- Explicit criteria maintain determinism while allowing flexible implementation

**Implementation:**
- Add `acceptance` array to requirement schema
- Each acceptance criterion maps to verification step
- Update TDD Red phase to write tests covering acceptance criteria
- Add acceptance criteria validation before marking passes: true

---

## 19. ~~Graceful Plan Regeneration~~ (Implemented)

**Status:** Implemented via `/tasks --refresh` flag.

See "Implemented" section above. Usage:

```bash
/tasks docs/tasks/prds/feature.json --refresh
```

**Refresh behavior:**
- Preserves requirements where `passes: true`
- Re-runs codebase analysis for incomplete requirements
- Updates `codeAnalysis` based on current code state
- Marks requirements `already-done` if implementation was discovered
- Logs refresh in notes file

---

## 20. Discovery-Aware Implementation

**Description:** Update plan with discoveries during implementation, not just completion status.

**Purpose:** Ralph emphasizes capturing learnings in the plan during execution. Future iterations benefit from past discoveries.

**Details:**
- Ralph's build prompt: "Update IMPLEMENTATION_PLAN.md with findings"
- Captures: encountered edge cases, discovered dependencies, relevant patterns
- Next iteration starts with enriched context
- Reduces re-discovery across iterations

**Implementation:**
- Add `discoveries` array to requirement schema
- Prompt Claude to log discoveries to notes AND update task JSON
- Show discoveries in task summary output
- Consider structured discovery types: patterns, dependencies, edge-cases, gotchas

---

## 21. Loop Iteration Visualization

**Description:** Add progress visualization and statistics to the loop wrapper.

**Purpose:** Ralph's loop.sh provides iteration counts and status. Autopilot's run.sh could be more informative.

**Details:**
- Current run.sh shows colorized output but limited statistics
- Add: current iteration, tasks completed this session, total tasks, ETA estimate
- Progress bar or percentage complete
- Stuck/blocked task warnings

**Implementation:**
- Enhance run.sh with richer output
- Add `--verbose` flag for detailed per-iteration logging
- Consider `--stats` flag for summary without full output
- Add JSON output mode for tooling integration

---

## 22. Prompt Language Patterns

**Description:** Adopt Ralph's specific language patterns that improve Claude's behavior.

**Purpose:** Certain phrasings trigger better behavior in Claude. Ralph documents these patterns.

**Details:**
- "study" instead of "read" - implies deeper understanding
- "don't assume not implemented" - triggers search behavior
- "using parallel subagents" - triggers parallelization
- "Ultrathink" - triggers extended reasoning
- "capture the why" - encourages documentation of rationale

**Implementation:**
- Audit and update all command markdown files
- Create glossary of preferred terms in CLAUDE.md
- Add to AGENTS.md as "Language Patterns" section
- Document reasoning behind each pattern choice

---

## 23. ~~Explicit Phase Numbering~~ (Implemented)

**Status:** Implemented in `/tasks` command.

See "Implemented" section above. The `/tasks` command now uses:
- Phase 0 (0a-0d): Codebase Analysis - extract keywords, search, study, document
- Phase 1: Gap Analysis - categorize requirements
- Phase 2: Task Generation - create enriched JSON
- Phase 3: Dependency Inference - auto-detect dependencies
- Phase 4: Review and Save - user confirmation

**Future:** Apply same structure to `autopilot.md` (Phase 99999+ guardrails).

---

## 24. ~~Single Source of Truth Guardrail~~ (Implemented)

**Status:** Implemented in `autopilot.md` and `AGENTS.md`.

Added as guardrail 999999999 in `autopilot.md` Phase 99999 section:
- Search for existing equivalent functionality before creating new code
- Prefer extending over creating parallel implementations
- Consolidate duplicates discovered during refactor
- Log consolidations to notes

Also added to `AGENTS.md` Guardrails section for cross-project visibility.

---

## 25. ~~Complete Implementation Guardrail~~ (Implemented)

**Status:** Implemented in `autopilot.md` and `AGENTS.md`.

Added as guardrail 99999999 in `autopilot.md` Phase 99999 section:
- No TODO/FIXME comments in committed code
- No placeholder functions or stub implementations
- No partial implementations with "will fix later"
- If blocked: mark `stuck: true`, add `blockedReason`, move to next requirement

Also added to `AGENTS.md` Guardrails section for cross-project visibility.

---

## Summary Priority

| Priority | Suggestions | Status |
|----------|-------------|--------|
| **Implemented** | 1, 4, 5, 6, 19, 23, 24, 25 | Done via `/tasks` enhancements and guardrails |
| **High** | 18 | Acceptance-driven test requirements (remaining) |
| **Medium** | 2, 7, 8, 10, 16, 22 | Workflow enhancements |
| **Low** | 3, 9, 11-15, 17, 20, 21 | Nice-to-have features |

---

## Next Steps

1. ~~Implement gap analysis in /tasks~~ Done
2. ~~Apply phase numbering and guardrails to autopilot.md~~ Done
3. Test the enhanced `/tasks` command on a real project
4. Consider implementing #18 (acceptance-driven test requirements)

---

*Generated from analysis of:*
- `/home/joe/Sites/autopilot` - Current autopilot implementation
- `/home/joe/Sites/ralph-playbook` - Geoffrey Huntley's Ralph Playbook
