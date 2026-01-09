# Rule: Generating a Product Requirements Document (PRD)

## Goal

To guide an AI assistant in creating a detailed, human-readable Product Requirements Document (PRD) in Markdown format. The PRD is for discussion and approval before implementation.

## Process

1.  **Receive Initial Prompt:** The user provides a brief description or request for a new feature or functionality.
2.  **Ask Clarifying Questions:** Before writing the PRD, the AI *must* ask only the most essential clarifying questions needed to write a clear PRD. Limit questions to 3-5 critical gaps in understanding. The goal is to understand the "what" and "why" of the feature, not necessarily the "how" (which the developer will figure out). Make sure to provide options in letter/number lists so I can respond easily with my selections.
3.  **Generate PRD:** Based on the initial prompt and the user's answers to the clarifying questions, generate a PRD using the structure outlined below.
4.  **Save PRD:** Save the generated document as `[feature-name].md` inside the `/docs/tasks/prds/` directory. Create the directory if needed.

## Clarifying Questions (Guidelines)

Ask only the most critical questions needed to write a clear PRD. Focus on areas where the initial prompt is ambiguous or missing essential context. Common areas that may need clarification:

*   **Problem/Goal:** If unclear - "What problem does this feature solve for the user?"
*   **Core Functionality:** If vague - "What are the key actions a user should be able to perform?"
*   **Scope/Boundaries:** If broad - "Are there any specific things this feature *should not* do?"
*   **Success Criteria:** If unstated - "How will we know when this feature is successfully implemented?"

**Important:** Only ask questions when the answer isn't reasonably inferable from the initial prompt. Prioritize questions that would significantly impact the PRD's clarity.

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
7.  **Open Questions:** List any remaining questions or areas needing further clarification.

## Target Audience

Assume the primary reader of the PRD is a **human** who will review and approve before implementation. Keep it readable and well-organized.

## Output

*   **Format:** Markdown (`.md`)
*   **Location:** `/docs/tasks/prds/`
*   **Filename:** `[feature-name].md`

## Next Step

After the PRD is approved, use `/tasks [prd-file]` to convert it to a machine-readable JSON format for autopilot execution.

## Final instructions

1. Do NOT start implementing the PRD
2. Make sure to ask the user clarifying questions
3. Take the user's answers to the clarifying questions and improve the PRD
