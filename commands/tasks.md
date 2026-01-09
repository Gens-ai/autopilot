# Rule: Converting PRD to Machine-Readable Tasks (TDD)

## Goal

Convert an approved human-readable PRD into a machine-readable JSON task file that autopilot can execute autonomously using Test-Driven Development.

## TDD Workflow

For each requirement, autopilot will:
1. **Red** - Write a failing test that defines the expected behavior
2. **Green** - Write minimal code to make the test pass
3. **Refactor** - Clean up while keeping tests green

## Input

User provides a path to an approved PRD file: `/tasks docs/tasks/prds/feature-name.md`

## Output

- **Format:** JSON (`.json`)
- **Location:** Same directory as the PRD
- **Filename:** Same name as PRD but with `.json` extension

## Process

1. **Read the PRD:** Parse the provided markdown PRD file
2. **Extract Requirements:** Identify all requirements from the PRD
3. **Structure for TDD:** For each requirement, create test and implementation sub-tasks
4. **Present for Review:** Show the user the generated JSON structure
5. **Save:** After user confirms, save the JSON file

## JSON Structure

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
      "tdd": {
        "test": {
          "description": "Write test for: [requirement description]",
          "file": "path/to/expected/test/file.test.ts",
          "passes": false
        },
        "implement": {
          "description": "Implement: [requirement description]",
          "passes": false
        },
        "refactor": {
          "description": "Refactor if needed, keep tests green",
          "passes": false
        }
      },
      "verification": [
        "Step to verify this requirement is complete",
        "Another verification step"
      ],
      "passes": false
    }
  ]
}
```

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
- Suggest test file paths based on project conventions

## Next Step

After generating the JSON, use `/autopilot [json-file]` to run autonomous TDD execution.
