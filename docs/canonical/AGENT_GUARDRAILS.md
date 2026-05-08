# Agent Guardrails

## Purpose

This file defines how coding, planning, design, and documentation agents must interpret and modify the **Life In Sync** product.

Agents must protect the canonical product model, avoid scope creep, and make narrow, verifiable changes only.

Before proposing features, architecture, data models, navigation, or UI structure, read:

1. `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
2. `docs/architecture/ARCHITECTURE.md`
3. Relevant supporting docs in `docs/`

This file is not a feature spec. It is a guardrail layer for agent behavior.

---

## Source of Truth Hierarchy

When product materials conflict, use this order:

1. `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
2. `docs/architecture/ARCHITECTURE.md`
3. Current implementation in the app codebase
4. Supporting docs in `docs/`
5. Explicit user instruction in the current task
6. Legacy briefs, notes, exports, or archived planning material

Legacy files are not authoritative when they conflict with the canonical spec.

`life-in-sync-source.txt` must not be treated as a migration requirement, implementation checklist, or active product mandate.

---

## Non-Negotiable Product Rules

Agents must not:

- Invent new top-level modules.
- Rename canonical modules unless the canonical spec is updated.
- Merge module responsibilities for convenience.
- Treat stale legacy briefs as the source of truth.
- Add login, cloud sync, accounts, collaboration, sharing, or multi-user features to v1 unless explicitly requested and reflected in canonical scope.
- Convert the app into a web-first or cross-platform architecture unless explicitly requested.
- Expand v1 into a full life-management platform beyond the canonical module boundaries.

Required assumptions:

- The app is native SwiftUI.
- The app is local-first in v1.
- The dashboard is the root home.
- Module switching is shell-level navigation.
- Each module owns its own domain.
- v1 prioritizes usefulness, stability, and clear user control over broad automation.

---

## Canonical Module Boundary Rules

Agents must preserve module boundaries.

### Supply List

Supply List must not become:

- Pantry management
- Inventory management
- Barcode scanning
- Store-price optimization
- Household procurement automation
- A grocery delivery system

Supply List is for lightweight user-managed list behavior unless canonical scope says otherwise.

### Task Protocol

Task Protocol must not become:

- Full project management
- Jira/Trello replacement
- Team collaboration software
- Gantt chart system
- Complex dependency graph tooling

Task Protocol is for structured task execution, not enterprise workflow management.

### Garage

Garage must not claim or imply:

- Real-time swing coaching
- Computer vision biomechanics analysis
- Medical, physical therapy, or injury diagnosis
- Guaranteed performance improvement
- Unsupported club/path/face measurements

Garage may guide practice structure, drills, sessions, notes, progress, and user-driven reflection within canonical scope.

### AI Behavior

AI must remain assistive, not autonomous.

Agents must not implement AI that:

- Silently writes user data.
- Makes irreversible changes without user confirmation.
- Creates records without clear user intent.
- Pretends to observe real-world behavior it cannot actually observe.
- Claims certainty from incomplete local data.
- Replaces user judgment in coaching, planning, purchasing, or task decisions.

AI may suggest, summarize, classify, recommend, or draft when the user remains in control.

---

## Implementation Discipline

Before proposing or making implementation changes, verify:

- The feature belongs to a canonical module.
- The feature is in v1 scope or explicitly marked deferred.
- The change does not violate AI, data, or module-boundary rules.
- The change is necessary for the requested task.
- The change can be validated.

If any check fails, stop and call out the conflict.

Agents must not “improve,” “modernize,” “generalize,” “clean up,” or “future-proof” architecture unless the user explicitly requested that exact scope.

Small tasks require small diffs.

---

## File Editing Rules

Agents must:

- Keep edits narrow and directly tied to the request.
- Prefer modifying existing files over creating new architecture.
- Name new files according to existing project conventions.
- Preserve public APIs unless the task explicitly requires changing them.
- Avoid drive-by formatting, renaming, or unrelated cleanup.
- Avoid moving code across modules unless required and explained.
- Avoid deleting legacy code unless the task explicitly asks for removal or the code is proven unreachable.

Agents must not touch unrelated modules to “make things cleaner.”

---

## SwiftData / Persistence Rules

Agents must treat model and persistence changes as high-risk.

Do not change SwiftData models, stored property names, relationships, identifiers, or persistence behavior unless explicitly required.

Before changing data models, agents must identify:

- Existing persisted models affected
- Migration risk
- Backward compatibility concerns
- Whether the task can be solved without model changes

If a model change is unavoidable, the response must clearly state the migration impact.

---

## Navigation Rules

Agents must preserve canonical navigation structure.

- Dashboard remains root home.
- Module switching remains shell-level.
- Modules should not own global navigation.
- A module should not directly hijack another module’s flow.
- Deep links, shortcuts, or handoffs must preserve domain ownership.

Do not add new navigation layers just to solve local screen complexity.

---

## UI / UX Rules

Agents must not create generic redesigns.

UI work must:

- Preserve the product’s existing design language unless the task requests a redesign.
- Reduce density when the user identifies clutter.
- Keep primary actions clear and reachable.
- Avoid decorative UI that does not improve comprehension or task flow.
- Avoid adding explanatory text as a substitute for better structure.
- Respect native SwiftUI patterns.

For Garage specifically:

- Drill UI should support goals, tasks, reps, time targets, streaks, and qualitative outcomes.
- Do not assume every drill is rep-based.
- Do not force “pass conditions” into Focus Room if the current product direction removes them.
- Do not overload Focus Room with full drill-library metadata.

---

## Refactor Safety Rules

Refactors must be bounded.

Before refactoring, agents must identify:

- Exact files affected
- Reason the refactor is necessary
- Behavior that must remain unchanged
- Validation method

Agents must not combine feature work, visual redesign, model changes, and architecture refactors in one pass unless explicitly requested.

If a refactor is too broad, propose phases instead of executing a risky sweep.

---

## Ambiguity Handling

When ambiguity exists, use this decision order:

1. Follow `docs/canonical/CANONICAL_PRODUCT_SPEC.md`.
2. Follow `docs/architecture/ARCHITECTURE.md`.
3. Follow relevant supporting docs in `docs/`.
4. Follow existing app behavior.
5. Follow the user’s current explicit request.
6. Ask for clarification only if the decision would materially affect architecture, data, or scope.

Do not invent behavior to avoid asking a necessary question.

Do not treat ambiguous requests as permission to expand scope.

---

## Hard Stop Conditions

Agents must stop and report the conflict if a request would require:

- A new top-level module
- Renaming canonical modules
- Adding login, cloud sync, collaboration, or accounts to v1
- Making AI autonomous
- Silent AI writes to user data
- Merging module responsibilities
- Expanding a module beyond canonical scope
- Changing persistence models without explicit approval
- Treating stale docs as authoritative over canonical docs
- Making unsupported coaching, health, biomechanics, or real-time analysis claims

The response should explain the conflict and offer a compliant alternative.

---

## Validation Requirements

After code changes, agents must run appropriate validation when available.

Preferred checks:

- `git diff --check`
- Project build command, usually `xcodebuild`
- Targeted tests if tests exist
- Swift compile validation when available

Agents must not claim a command passed unless it was actually run.

If validation was not run, say so clearly and explain why.

---

## Required Agent Response Format

After implementation, agents must respond with:

1. **Files Changed**
2. **What Changed**
3. **Preserved Behavior**
4. **Validation**
5. **Known Risks / Notes**

Keep the summary factual and concise.

Do not include inflated praise, vague confidence claims, or broad architectural commentary unless requested.

---

## Forbidden Claims

Agents must not say:

- “Fully verified” unless all relevant validation was actually run.
- “Production-ready” unless the task included production-readiness criteria and validation passed.
- “No risk” for persistence, navigation, or model changes.
- “AI-powered” in a way that implies autonomy beyond canonical behavior.
- “Real-time coaching” unless the canonical spec explicitly supports it.

Use precise language.

---

## Planning Agent Rules

Planning agents must separate:

- Current canonical v1 scope
- Deferred ideas
- Explicit user requests
- Speculative future concepts

Planning agents must not backfill speculative ideas into v1 scope.

When proposing options, label them clearly as:

- **Safe Now**
- **Needs Canonical Spec Update**
- **Deferred**
- **Reject / Out of Scope**

---

## Coding Agent Rules

Coding agents must:

- Read relevant files before editing.
- Preserve existing behavior unless asked to change it.
- Avoid broad rewrites when a surgical fix works.
- Keep generated code consistent with existing naming, style, and project structure.
- Explain any unavoidable tradeoff.
- Validate changes before reporting completion when possible.

Coding agents must not:

- Create placeholder architecture.
- Add TODO-driven fake systems.
- Add unused abstractions.
- Introduce dependencies without explicit need.
- Change app-wide styling for a local UI request.

---

## Documentation Agent Rules

Documentation agents must:

- Keep docs aligned with canonical scope.
- Mark future ideas as deferred.
- Remove or flag conflicts with stale material.
- Avoid duplicating the canonical spec unnecessarily.
- Prefer concise, enforceable language over broad product philosophy.

Docs should clarify decisions, not create new ones.

---

## Final Rule

When unsure, preserve the canonical product and reduce scope.

Do not invent.
Do not expand.
Do not silently change data.
Do not merge domains.
Do not claim validation that was not performed.
