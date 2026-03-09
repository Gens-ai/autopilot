# Rule: Generating a Product Requirements Document (PRD)

## Goal

To guide an AI assistant in creating a detailed, human-readable Product Requirements Document (PRD) in Markdown format. The PRD is for discussion and approval before implementation.

## Process

1.  **Receive Initial Prompt:** The user provides a brief description or request for a new feature or functionality.
2.  **Ask Clarifying Questions:** Before writing the PRD, ask as many clarifying questions as a professional product manager or senior developer would ask a client before writing a spec. Ask at least 3-5 questions, but don't stop there — ask every question needed to fully specify the feature so the PRD has **zero open questions**. Think like a consultant being paid to deliver a complete spec: if something is ambiguous, underspecified, or could be interpreted multiple ways, ask about it. The goal is to understand the "what" and "why" thoroughly enough that the PRD is actionable without further clarification. Make sure to provide options in letter/number lists so the user can respond easily with selections.
3.  **Follow-up Questions:** After the user answers, review their responses. If any answers raise new questions, introduce ambiguity, or leave gaps — ask follow-up questions. Repeat until you are confident the PRD can be written with no open questions. Don't be afraid to ask 2-3 rounds of questions if needed.
4.  **Generate PRD:** Based on the initial prompt and all clarifying conversations, generate a PRD using the structure outlined below. The PRD must have **no Open Questions section** — all questions should have been resolved during clarification.
5.  **Save PRD:** Save the generated document as `[feature-name].md` inside the `docs/autopilot/[feature-name]/` directory. Create the directory if needed.

## Clarifying Questions (Guidelines)

Ask every question a professional product manager or senior developer would ask before writing a spec. Cover all areas where the initial prompt is ambiguous, underspecified, or could be interpreted multiple ways. Common areas to probe:

*   **Problem/Goal:** "What problem does this feature solve? Who experiences this problem?"
*   **Target Users:** "Who are the primary users? Are there secondary user types with different needs?"
*   **Core Functionality:** "What are the key actions a user should be able to perform?"
*   **Scope/Boundaries:** "Are there any specific things this feature *should not* do?"
*   **User Flows:** "Walk me through the ideal user journey. What happens at each step?"
*   **Edge Cases:** "What should happen when X fails? What about empty states, errors, rate limits?"
*   **Data & State:** "What data is created, read, updated, or deleted? What persists across sessions?"
*   **Permissions & Access:** "Who can see/do what? Are there role-based restrictions?"
*   **Integrations:** "Does this interact with external services, APIs, or other features?"
*   **Performance:** "Are there latency, throughput, or scale requirements?"
*   **UI/UX:** "Are there design preferences, existing patterns to follow, or accessibility requirements?"
*   **Success Criteria:** "How will we know when this feature is successfully implemented?"
*   **Constraints:** "Are there technical, timeline, or resource constraints?"
*   **Migration/Rollout:** "Is there existing data or behavior to migrate? Rollout strategy?"

**Important:** Don't skip a question just because you think you can infer the answer — if the user hasn't explicitly addressed it and it matters for the spec, ask. The cost of one extra question is far lower than an incomplete PRD.

### Formatting Requirements

- **Number all questions** (1, 2, 3, etc.)
- **List options for each question as A, B, C, D, etc.** for easy reference
- Make it simple for the user to respond with selections like "1A, 2C, 3B"

### Example Format

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Generate additional revenue

2. Who is the target user for this feature?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only
```

## PRD Structure

The generated PRD should include the following sections:

1.  **Introduction/Overview:** Briefly describe the feature and the problem it solves. State the goal.
2.  **Goals:** List the specific, measurable objectives for this feature.
3.  **User Stories:** Detail the user narratives describing feature usage and benefits.
4.  **Requirements:** List the specific requirements the feature must have. Use clear, concise language. Group by category:
    - **Functional**: Core business logic and features
    - **UI**: User interface and visual elements
    - **Integration**: Connections with other systems/modules
    - **Testing**: Test coverage requirements
5.  **Non-Goals (Out of Scope):** Clearly state what this feature will *not* include to manage scope.
6.  **Technical Considerations:** Mention any known technical constraints, dependencies, or suggestions.

**Note:** There is no "Open Questions" section. All questions must be resolved during the clarifying questions phase before the PRD is written. If you realize you have unresolved questions while drafting, stop and ask the user before continuing.

## Target Audience

Assume the primary reader of the PRD is a **human** who will review and approve before implementation. Keep it readable and well-organized.

## Output

*   **Format:** Markdown (`.md`)
*   **Location:** `docs/autopilot/[feature-name]/`
*   **Filename:** `[feature-name].md`

## Next Step

After the PRD is approved, use `/tasks [prd-file]` to convert it to a machine-readable JSON format for autopilot execution.

## Final instructions

1. Do NOT start implementing the PRD
2. Ask thorough clarifying questions — as many as needed, not just 3-5
3. Ask follow-up questions if the user's answers raise new ambiguities
4. Do NOT write the PRD until all questions are resolved
5. The final PRD must have ZERO open questions — if you find yourself wanting to add one, stop and ask the user instead
6. Take the user's answers to all clarifying questions and write a complete, actionable PRD
