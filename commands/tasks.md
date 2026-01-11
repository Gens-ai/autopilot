# Rule: Converting PRD to Machine-Readable Tasks (TDD)

## Goal

Convert an approved human-readable PRD into a machine-readable JSON task file that autopilot can execute autonomously using Test-Driven Development. **Before generating tasks, analyze the codebase to understand what exists, identify patterns, and scope implementation accurately.**

## TDD Workflow

For each requirement, autopilot will:
1. **Red** - Write a failing test that defines the expected behavior
2. **Green** - Write minimal code to make the test pass
3. **Refactor** - Clean up while keeping tests green

## Input

- **New tasks:** `/tasks docs/tasks/prds/feature-name.md`
- **Refresh existing:** `/tasks docs/tasks/prds/feature-name.json --refresh`

## Output

- **Format:** JSON (`.json`)
- **Location:** Same directory as the PRD
- **Filename:** Same name as PRD but with `.json` extension

---

## Phase 0: Codebase Analysis

**Before generating any tasks, thoroughly explore the codebase.**

### 0a. Extract Keywords from PRD

Read the PRD and identify:
- Core concepts and domain terms
- Technical components mentioned (models, controllers, services, etc.)
- Integration points (APIs, databases, external services)

### 0b. Search for Related Code

Using parallel subagents, search the codebase for:
- Files matching PRD keywords (use Glob and Grep)
- Existing implementations of similar features
- Related test files and test patterns
- Utilities, helpers, and shared code that could be reused

### 0c. Study Discovered Files

For each relevant file found:
- Understand its purpose and structure
- Identify patterns and conventions used
- Note reusable utilities and abstractions
- Check for partial implementations of PRD requirements

### 0d. Document Findings

Create a mental map of:
- **Existing code:** What already exists that relates to this feature
- **Patterns:** Architectural patterns, naming conventions, file organization
- **Utilities:** Shared code that can be leveraged
- **Gaps:** What's missing vs what the PRD requires

---

## Phase 1: Gap Analysis

**For each PRD requirement, determine what exists vs what needs to be built.**

### Assessment Categories

| Approach | When to Use |
|----------|-------------|
| `create` | Nothing exists; build from scratch |
| `extend` | Partial implementation exists; add to it |
| `modify` | Implementation exists but needs changes |
| `already-done` | Requirement is fully satisfied by existing code |

### For Each Requirement

1. Search for existing implementations that satisfy this requirement
2. Search for existing tests that cover this behavior
3. Identify specific files that would need modification
4. Determine the approach (create/extend/modify/already-done)
5. Note patterns to follow based on similar existing code

**Critical Rule:** Don't assume something isn't implemented. Always search first.

---

## Phase 2: Task Generation

Generate the JSON task file with enriched, code-aware information.

### JSON Structure

```json
{
  "name": "feature-name",
  "description": "Brief description from PRD overview",
  "goals": ["Goal 1", "Goal 2"],
  "nonGoals": ["What this feature will NOT do"],
  "technicalNotes": "Any constraints or dependencies from PRD",
  "_tdd": true,
  "_priority_order": [
    "1. Architectural decisions and core abstractions",
    "2. Integration points between modules",
    "3. Unknown unknowns and spike work",
    "4. Standard features and implementation",
    "5. Polish, cleanup, and quick wins"
  ],
  "_step_size": "One logical change per commit. Quality over speed.",
  "requirements": [
    {
      "id": "1",
      "category": "functional",
      "description": "Clear description of this requirement",
      "codeAnalysis": {
        "approach": "extend",
        "existingFiles": ["src/auth/UserService.ts"],
        "relatedTests": ["src/auth/__tests__/UserService.test.ts"],
        "patterns": ["Uses repository pattern", "Follows service layer conventions"],
        "targetFiles": {
          "modify": ["src/auth/UserService.ts"],
          "create": ["src/auth/PasswordResetToken.ts"]
        }
      },
      "tdd": {
        "test": {
          "description": "Add password reset tests to UserService.test.ts following existing test patterns",
          "file": "src/auth/__tests__/UserService.test.ts",
          "passes": false
        },
        "implement": {
          "description": "Add resetPassword() method to UserService, use existing EmailService for notifications",
          "passes": false
        },
        "refactor": {
          "description": "Extract token generation to shared utility if duplicated",
          "passes": false
        }
      },
      "verification": [
        "Reset token is generated and stored",
        "Email is sent via existing EmailService",
        "Password update invalidates token"
      ],
      "passes": false
    }
  ]
}
```

### Requirement Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier for ordering |
| `category` | Yes | `functional`, `ui`, or `integration` |
| `description` | Yes | Clear description of the requirement |
| `codeAnalysis` | Yes | Findings from Phase 0-1 (see below) |
| `dependsOn` | No | Array of requirement IDs that must complete first |
| `testType` | No | `unit`, `integration`, or `e2e` |
| `issue` | No | GitHub issue reference (e.g., `"#123"`) |
| `package` | No | Monorepo package name if applicable |
| `tdd` | Yes | Test, implement, refactor phases |
| `verification` | Yes | Steps to verify completion |
| `passes` | Yes | Set to `false` initially |

### codeAnalysis Object

| Field | Description |
|-------|-------------|
| `approach` | `create`, `extend`, `modify`, or `already-done` |
| `existingFiles` | Related files discovered during analysis |
| `relatedTests` | Existing test files to extend or reference |
| `patterns` | Patterns to follow based on existing code |
| `targetFiles.modify` | Specific files to modify |
| `targetFiles.create` | New files to create |

### Writing Code-Aware TDD Descriptions

**Bad (generic):**
```json
"test": { "description": "Write tests for password reset" }
"implement": { "description": "Implement password reset" }
```

**Good (code-aware):**
```json
"test": { "description": "Add password reset tests to UserService.test.ts, following existing createUser() test pattern" }
"implement": { "description": "Add resetPassword() to UserService, use existing TokenGenerator utility and EmailService" }
```

---

## Phase 3: Dependency Inference

Based on code analysis, infer dependencies between requirements:

1. If requirement A creates/modifies a file that requirement B depends on, add dependency
2. If requirement A creates a model that requirement B uses, add dependency
3. Present inferred dependencies to user for confirmation

---

## Phase 4: Review and Save

1. Present the complete JSON structure to the user
2. Highlight any requirements marked `already-done` (no implementation needed)
3. Show inferred dependencies for confirmation
4. After user confirms, save the JSON file

---

## Refresh Mode (`--refresh`)

When given an existing tasks JSON file with `--refresh`:

```
/tasks docs/tasks/prds/feature.json --refresh
```

### Refresh Behavior

1. **Preserve completed work:** Keep all requirements where `passes: true`
2. **Re-analyze incomplete:** Run Phase 0-1 for requirements where `passes: false`
3. **Update codeAnalysis:** Refresh file lists and approaches based on current code state
4. **Detect newly done:** Mark requirements `already-done` if implementation was completed outside autopilot
5. **Update notes:** Log refresh in the corresponding notes file

### When to Refresh

- Implementation went off-track and needs course correction
- Significant time passed since initial task generation
- Manual code changes affected the feature area
- Discoveries during implementation changed the landscape

---

## Requirement Categories

- **functional**: Core business logic and features
- **ui**: User interface and visual elements
- **integration**: Connections with other systems/modules

## TDD Rules

1. **Test First**: Never write implementation before the test exists
2. **Minimal Implementation**: Write only enough code to pass the test
3. **One Requirement at a Time**: Complete full TDD cycle before moving on
4. **Tests Must Fail First**: Verify the test fails before implementing
5. **Tests Must Pass After**: Verify the test passes after implementing

## Important Notes

- Each requirement has three phases: test → implement → refactor
- The `tdd.test.passes` must be true before starting `tdd.implement`
- The `tdd.implement.passes` must be true before starting `tdd.refactor`
- The requirement's `passes` becomes true only when all three phases complete
- Use specific file paths based on codebase analysis, not guesses
- Reference existing patterns and utilities in descriptions
- If `approach` is `already-done`, the requirement needs no implementation

## Next Step

After generating the JSON, use `/autopilot [json-file]` to run autonomous TDD execution.
