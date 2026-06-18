---
name: brainstorming
description: Design-first workflow for turning unclear or high-impact ideas into approved specs before implementation. Use for exploratory features, architecture, navigation, persistence, audio/session behavior, multi-screen flows, or major redesigns that require decisions before coding. Do not use as a mandatory gate for small fixes or already-approved implementation work.
---

# Brainstorming

Use this skill to turn a rough or materially ambiguous idea into an approved design and written spec before implementation.

Do not invoke it merely because work changes UI or behavior. Small fixes and implementation of an already-approved contract should follow the repository's normal inspect, implement, and verify workflow.

## Hard Gate

Do not write code, scaffold files, change behavior, or invoke implementation-oriented skills until:

1. The design has been presented.
2. The user has approved it.
3. The written spec has been reviewed by the user.

This applies only when the request is genuinely exploratory or affects architecture, navigation, persistence, data models, audio/session behavior, app-wide styling, multi-screen flows, or a major redesign. It does not block surgical fixes, documentation maintenance, or implementation explicitly approved by the user.

## Workflow

Complete these steps in order.

1. Explore project context.
   Read the relevant files, docs, and recent commits before proposing solutions.
   In an existing codebase, follow current patterns and constraints.

2. Decide whether a visual companion would help.
   If upcoming questions will be easier to answer with mockups, diagrams, or layout comparisons, offer the visual companion in its own message and nothing else:

   `Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)`

   If the user accepts, read [visual-companion.md](./visual-companion.md) before continuing.

3. Ask focused clarifying questions.
   Prefer multiple-choice questions when practical.
   Batch related decisions when the user requests rapid-fire questions or when one compact set will reduce unnecessary turns.
   Focus on purpose, constraints, non-goals, and success criteria.
   If the request is too large for one spec, stop and help the user decompose it into smaller projects. Then brainstorm only the first slice.

4. Propose 2-3 approaches.
   Lead with the recommended option.
   Explain tradeoffs briefly and concretely.

5. Present the design.
   Scale the depth to the problem.
   Cover the pieces that matter: architecture, components, data flow, failure handling, and testing.
   For non-trivial work, present the design in sections and confirm each section before moving on.

6. Write the design doc after the user approves the direction.
   Save it to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` unless the user asked for a different location.

7. Self-review the spec and fix issues inline.
   Check for:
   - placeholders such as `TODO`, `TBD`, or incomplete sections
   - contradictions between sections
   - scope that is too large for one implementation plan
   - ambiguous requirements that could be implemented more than one way

8. Ask the user to review the written spec.
   Use this exact prompt:

   `Spec written at <path>. Please review it and let me know if you want to make any changes before we start writing out the implementation plan.`

   Wait for approval. If changes are requested, update the spec and repeat the self-review. Do not commit unless the user explicitly asks for a commit.

9. Transition to planning.
   If a `writing-plans` skill is available, invoke it after the user approves the spec.
   Do not invoke implementation skills here.

## Working Style

- Keep questions focused; batch related decisions when that is more efficient or explicitly requested.
- Keep momentum, but do not skip validation steps.
- Be ruthless about YAGNI.
- Prefer small, well-bounded units with clear interfaces.
- Include only targeted refactors that directly support the current goal.
- If existing code has architectural problems that affect the design, address only the parts necessary to make the current work clean and safe.

## Output Expectations

When using this skill:

- Do not jump straight to a solution.
- Do not present only one path unless alternatives are genuinely not viable.
- Do not move into implementation after verbal approval alone; the written spec review is also required.
- Keep the design concrete enough that the next planning step can produce an implementation plan without re-litigating core decisions.
