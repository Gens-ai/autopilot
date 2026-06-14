# Rule: Convert User Story Domain File to Testing Tasks

## Goal

Parse a user story domain file and generate an autopilot task JSON optimized for **testing existing features** rather than implementing new ones. Each user story becomes a discrete testable requirement executed in a fresh session with its own context window.

**Key distinction from `/tasks`:** The TDD phases are repurposed for testing:
- **Test** → Navigate to the feature in the browser and execute the story flow; also inspect relevant code
- **Implement** → Write the inline finding directly into the domain file
- **Refactor** → Inspect permission/access control code; run negative browser tests on high-stakes features

A requirement's `passes: true` means **the story has been fully tested and documented** — not that the feature works correctly. Bugs and missing features are expected findings, not failures of the testing task.

## Input

```
/test-user-stories docs/testing/domains/01-feature-area.md
```

## Output

Task JSON saved to: `docs/autopilot/testing/{domain-name}/{domain-name}.json`

Then run:
```
/autopilot docs/autopilot/testing/{domain-name}/{domain-name}.json
```

---

## Phase 0: Pre-flight

Before generating any tasks:

1. **Read the domain file** at the provided path — confirm it exists and contains user stories (look for `**US-` bold pattern)
2. **Read CLAUDE.md** — find the `## Testing Configuration` section for: test URL, available accounts, screenshot directory, and any project-specific notes
3. **Count stories** — report to the user: total story count, any inherited sections, any accounts flagged as "must be created"
4. **Create output directory** — `docs/autopilot/testing/{domain-name}/` if it doesn't exist

---

## Phase 1: Parse Domain File

Scan the domain file and extract:

### User Stories

Identify each story by the bold ID pattern: `**US-XXX-XX**` or `**US-XXX**`

For each story, extract:
- **Story ID** (e.g., `US-REG-01`)
- **Full story text** ("As a X, I want to Y so that Z")
- **Role** (from the surrounding section heading)
- **Section** (e.g., "1.1 Registration", "7.2 Forum Management")
- **High-stakes flag** — mark `true` if the section involves: financials, payments, member management, permissions, role assignment, or destructive actions; these get negative browser testing in the refactor phase
- **Inherited flag** — mark `true` if the story appears under a heading containing "inherits" or "Inherits"

### Setup Prerequisite

Check the "Accounts Needed" section at the top of the domain file. If any accounts are marked as "must be created," generate a **single SETUP requirement** as the first task to handle account creation before story testing begins.

### Summary Placeholder

Always generate a **SUMMARY requirement** as the final task to write the triage summary to the domain file and update the README status.

---

## Phase 2: Codebase Discovery

For each story, run a targeted codebase search to find the relevant implementation. The exact directories depend on your stack — adapt the search to the project's framework:

- **Route / endpoint** — search route files, API definitions, or URL config for the path implied by the story
- **UI component** — search component, view, or page files for the feature area
- **Controller / handler** — search controller, action, or handler files for the story's core operation
- **Admin panel resource** — if the story involves a management UI, search admin panel or dashboard files
- **Permission gate** — grep near found files for authorization patterns (middleware, policy checks, role guards, `can`/`authorize` calls, etc.)

Populate `codeAnalysis` fields with findings. If nothing is found for a story, set `approach: "missing"` — the feature may not be implemented at all.

---

## Phase 3: Task Generation

### JSON Wrapper

```json
{
  "name": "{domain-name}",
  "description": "Testing run for {domain title} user stories",
  "goals": [
    "Verify each user story is implemented and behaves as described",
    "Identify missing features, broken flows, and permission gaps",
    "Document all findings inline in the domain file",
    "Produce a severity-triaged summary at the end of the domain file"
  ],
  "nonGoals": [
    "Fix discovered issues (document only)",
    "Implement missing features",
    "Test features outside this domain file"
  ],
  "_tdd": true,
  "_testing_mode": true,
  "requirements": []
}
```

---

### SETUP Requirement (only if missing accounts exist in domain file)

```json
{
  "id": "SETUP",
  "category": "testing",
  "description": "Create missing role accounts required for this domain before testing begins",
  "codeAnalysis": {
    "approach": "test",
    "existingFiles": [],
    "relatedTests": [],
    "patterns": [],
    "targetFiles": { "modify": [], "create": [] }
  },
  "acceptance": [
    "All accounts listed in the domain file 'Accounts Needed' section exist and can log in at the test URL"
  ],
  "tdd": {
    "test": {
      "description": "Attempt to log in with each account listed in the domain file's 'Accounts Needed' section. Identify which accounts do not yet exist.",
      "file": "",
      "passes": false
    },
    "implement": {
      "description": "For each missing account: follow the creation commands in the domain file's setup section (tinker or admin UI). Verify each new account can authenticate before moving on.",
      "passes": false
    },
    "refactor": {
      "description": "Confirm all required accounts exist and have the correct roles assigned. No code inspection needed for this setup step.",
      "passes": false
    }
  },
  "verification": [
    "Every account in the domain file 'Accounts Needed' table can log in successfully at the test URL"
  ],
  "passes": false
}
```

---

### Per-Story Requirements

Generate one requirement per user story using this structure:

```json
{
  "id": "US-XXX-XX",
  "category": "testing",
  "description": "Full story text: As a X, I want to Y so that Z",
  "_role": "Role name from section context",
  "_section": "Section number and title",
  "_highStakes": false,
  "_inherited": false,
  "codeAnalysis": {
    "approach": "test",
    "existingFiles": ["routes discovered in phase 2", "components discovered in phase 2"],
    "relatedTests": [],
    "patterns": ["Permission pattern found, e.g. 'Uses middleware permission:view-events'"],
    "targetFiles": {
      "modify": ["path/to/domain-file.md"],
      "create": []
    }
  },
  "acceptance": [
    "Derived from the story: what specifically must be true for this to work?",
    "Happy path: the core action succeeds as described",
    "Edge case implied by the story (e.g., cancelling an action that was just taken)",
    "Edge case: validation or error state the story implies",
    "Additional edge cases the agent identifies as relevant"
  ],
  "tdd": {
    "test": {
      "description": "Log in as {role} at the test URL. Navigate to {feature area}. Perform the action described in the story. Observe the full flow. Also test: {story-implied edge cases} and any additional edge cases that seem risky or likely to break.",
      "file": "path/to/domain-file.md",
      "passes": false
    },
    "implement": {
      "description": "Write inline finding(s) directly after **US-XXX-XX** in the domain file. One bullet per distinct finding. Use format: '- no issue' / '- fix: <what is broken>' / '- feature: <what is missing>' / '- suggestion: <improvement>' / '- blocked: <reason>'. If a critical or moderate issue was found, take a screenshot and save to the project's screenshot directory (see CLAUDE.md testing configuration). Name it: US-XXX-XX-short-description.png",
      "passes": false
    },
    "refactor": {
      "description": "Read {found files from codeAnalysis.existingFiles}. Confirm permission gates exist and make sense for this story. Flag as '- fix: no permission check found' if none exists. [HIGH-STAKES ONLY: also open a browser tab as an unauthorized role and confirm they are blocked from this feature — document the result as an additional inline comment.]",
      "passes": false
    }
  },
  "verification": [
    "At least one inline comment exists after US-XXX-XX in the domain file",
    "Permission code was read and assessed",
    "Screenshot saved if a critical or moderate finding was documented"
  ],
  "passes": false
}
```

**When deriving `acceptance` criteria from a story:**
- The "so that" clause tells you what to verify
- Paired actions (create/delete, RSVP/cancel, enable/disable) should both be listed
- Validation states are almost always implied — include them
- Add any edge cases that seem risky given the feature area

---

### Inherited Story Requirements

For stories flagged `_inherited: true`, generate a single consolidated spot-check requirement per inherited block rather than one per story:

```json
{
  "id": "US-{ROLE}-INHERITED-{PARENT-ROLE}",
  "category": "testing",
  "_inherited": true,
  "_inheritsFrom": "Parent role name",
  "description": "Spot-check: verify {inheriting role} inherits {parent role} capabilities as documented",
  "acceptance": [
    "2-3 representative stories from the inherited set work for the inheriting role",
    "The inheriting role's permission set includes the parent role's permissions in code"
  ],
  "tdd": {
    "test": {
      "description": "Log in as {inheriting role}. Pick 2-3 representative stories from the inherited set — prefer ones that cover different feature areas. Test each. If the parent role's stories had issues, test the same stories here to see if they're shared.",
      "file": "path/to/domain-file.md",
      "passes": false
    },
    "implement": {
      "description": "Write a single inline note under the 'inherits' section heading in the domain file: '- inherited from {parent role} — spot-checked {story IDs}: {result}'",
      "passes": false
    },
    "refactor": {
      "description": "Check role definitions in the permissions seeder or equivalent to confirm the inheriting role explicitly includes the parent role's permissions. Note any gaps.",
      "passes": false
    }
  },
  "passes": false
}
```

---

### SUMMARY Requirement (always last)

```json
{
  "id": "SUMMARY",
  "category": "testing",
  "description": "Write severity-triaged summary at the bottom of the domain file and mark the domain complete in the README",
  "codeAnalysis": {
    "approach": "test",
    "existingFiles": [],
    "relatedTests": [],
    "patterns": [],
    "targetFiles": {
      "modify": [
        "{path/to/domain-file.md}",
        "{path/to/domain-index/README.md}"
      ],
      "create": []
    }
  },
  "acceptance": [
    "A '## Test Run Summary' section exists at the bottom of the domain file",
    "Summary includes: run date, total stories tested, counts per finding type (no-issue / fix / feature / suggestion / blocked)",
    "Summary includes a severity-triaged list: Critical, Moderate, Minor",
    "README.md status for this domain updated to ✅ Complete"
  ],
  "tdd": {
    "test": {
      "description": "Read all inline findings from the domain file. Count: total stories, no-issue count, fix count, feature count, suggestion count, blocked count. For each fix/feature/suggestion, assign severity — Critical (broken or data/security risk), Moderate (wrong behavior or important UX gap), Minor (cosmetic or non-essential). Note any story that has no inline comment at all.",
      "file": "{path/to/domain-file.md}",
      "passes": false
    },
    "implement": {
      "description": "Append a '## Test Run Summary' section to the bottom of the domain file containing: run date, story counts, finding counts, and the full severity-triaged list of all fix/feature/suggestion items with story IDs and one-line descriptions. Then update the domain index README to change this domain's status to ✅ Complete.",
      "passes": false
    },
    "refactor": {
      "description": "Scan for any story that was not documented (no inline comment). Add '- not tested' after any missed story. Verify the README was updated correctly.",
      "passes": false
    }
  },
  "verification": [
    "'## Test Run Summary' section is present at the bottom of the domain file",
    "All three severity tiers are listed (or noted as empty)",
    "README.md shows ✅ for this domain"
  ],
  "passes": false
}
```

---

## Phase 4: Review and Save

Report to the user:
- Total requirements generated (SETUP if needed + stories + SUMMARY)
- Stories where `codeAnalysis.approach` is `"missing"` (no code found — likely unimplemented)
- High-stakes stories flagged for negative browser testing
- Any inherited blocks consolidated into spot-checks

Save the JSON to `docs/autopilot/testing/{domain-name}/{domain-name}.json`

Tell the user the next command:
```
/autopilot docs/autopilot/testing/{domain-name}/{domain-name}.json
```

---

## Severity Reference (for SUMMARY requirement)

| Severity | Criteria |
|---|---|
| **Critical** | Feature is broken or unusable, OR a data loss / security / permission leak risk exists |
| **Moderate** | Feature works but produces incorrect behavior, or an important UX gap makes it hard to use |
| **Minor** | Cosmetic issue, polish suggestion, or a non-essential missing detail |

---

## Blocker Reference

| Situation | Action |
|---|---|
| Missing account | Handle in SETUP requirement; if discovered mid-run, create via admin UI or framework CLI and note what was done |
| Missing test data | Create minimal data via admin UI or framework CLI; document in the inline comment |
| External service not configured (e.g., Stripe, email) | Test UI-only portions; mark send/charge actions as `- blocked: {service} not configured on test tenant` |
| Feature URL returns 404 or 500 | Mark `- fix: route returns {status}` and move on |
| Cannot reproduce — environment issue | Mark `- blocked: could not reproduce, suspected env issue` |

---

## Comment Format Reference

```
- no issue
- fix: <what is broken and how>
- feature: <what is missing>
- suggestion: <improvement that is not a bug>
- blocked: <why testing could not complete>
```

Multiple findings on one story = multiple bullets. **Always write at least one bullet per story.**
