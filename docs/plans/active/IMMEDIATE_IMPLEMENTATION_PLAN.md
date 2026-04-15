# Immediate Implementation Plan (Next 2-4 Weeks)

## Status: active implementation plan (time-bound).


## Objective
Translate the latest product direction into shippable architecture and module scaffolding while protecting canonical boundaries and local-first behavior.

## Guardrails (Must Hold)
- Canonical module names and boundaries remain unchanged
- No autonomous AI writes
- Offline-first for non-AI flows
- Usefulness and clarity over visual novelty
- The V1 Module Depth Contract in `docs/canonical/IMPLEMENTATION_CONTRACT.md` remains authoritative for "first real depth"

## Phase 1: Lock Shared Patterns (Foundation)
### 1.1 Command-center module hub template
Define and document one reusable template used by deep modules:
- top hero status region
- “current state” block
- “next attention” block
- module-local bottom tab scaffold

Deliverables:
- shared hub layout contract (view + view model responsibilities)
- consistent spacing/typography rules for hub sections
- module-tab naming conventions (clear, non-cute labels)

### 1.2 Dashboard card contract v2
Define a single card schema for dashboard module entry:
- progress summary
- urgency/importance indicator (quiet style)
- direct tap target into module hub

Deliverables:
- dashboard card data model contract
- ranking policy: urgency first, importance second
- dashboard three-zone layout contract:
  - top: daily focus + key metric
  - middle: module pulse strip
  - bottom: timeline + quiet alerts

### 1.3 Visual system + composition primitives
Define reusable visual primitives across modules:
- spacing scale tokens
- typography hierarchy tokens
- surface layer rules
- module visualization container contract

Deliverables:
- design-token baseline for spacing/type/surface/color roles
- module composition rule: Hero -> Visualization -> Contextual Actions -> Activity Feed

### 1.4 AI orb + compact panel contract
Define global assistant invocation and panel behavior:
- orb placement rules
- module-context payload passed to assistant
- guided-input flow structure
- approve/reject checkpoint before any write

Deliverables:
- assistant interaction state model
- module-specific rejection reason taxonomy (initial set)

## Phase 2: Scaffold Priority Depth Modules (Structure Only)
This phase is limited to shared command-center scaffolding for depth modules.

In-scope for this phase:
- module hub structure
- internal tab scaffolds
- light routing and placeholder surfaces

Out-of-scope for this phase:
- first full feature depth for these modules
- replacing the V1 Module Depth Contract sequencing

### 2.1 Capital Core (Money)
Implement module hub + internal tabs and thin baseline flows.

Minimum internal tabs:
- Overview
- Entries
- Advisor (optional surface, user-triggered)

### 2.2 Iron Temple (Workouts)
Implement hub + tabs with builder and advisor separation (thin baseline).

Minimum internal tabs:
- Overview
- Builder
- Advisor

### 2.3 Garage
Implement hub + tabs with clear state and action pathways (thin baseline).

Minimum internal tabs:
- Overview
- Records
- Review

## Phase 3: Launch and Dashboard Refinement
### 3.1 Affirmation launch moment
Add a ~4-second affirmation screen with offline fallback content.

Acceptance notes:
- app remains reliable and deterministic
- failures degrade gracefully to local fallback quote/verse

### 3.2 Dashboard rebalance
Adjust dashboard to represent all modules without over-focusing one area.

Acceptance notes:
- progress-first information hierarchy
- direct entry to module hubs
- quiet urgency signaling

## Phase 4: System Consistency Pass
Apply common CRUD/support behaviors across modules where relevant:
- history/archive behavior
- tags strategy
- filter/sort consistency
- confirmation and undo patterns

## Acceptance Checklist
A slice is considered complete when:
- deep modules share the same hub architecture pattern
- dashboard uses the new progress-first entry contracts
- AI orb and compact panel are consistent across enabled modules
- no AI write occurs without explicit confirmation
- canonical module naming remains intact in docs and code

## Risks and Mitigations
- Risk: UI divergence between modules
  - Mitigation: enforce shared hub contract before custom surfaces
- Risk: AI scope creep into autonomous behavior
  - Mitigation: explicit write-approval gate and contract tests
- Risk: dashboard bloat
  - Mitigation: keep dashboard informational + routing only

## Recommended Execution Order
1. Shared hub template + dashboard card contract
2. Visual system + composition primitives
3. AI orb/assistant panel contract
4. Capital Core + Iron Temple + Garage hub/tabs
5. Launch affirmation flow
6. Dashboard rebalance
7. CRUD/history/tags consistency pass
8. Continue first real feature depth in Habit Stack / Task Protocol / Calendar / Supply List per implementation contract

## Simple Step-by-Step (ELI5)
Use this sequence like a checklist:

1. Build one reusable “module home” template.
   - Make the top status area, current state section, and next-action section once.
2. Make one reusable dashboard card.
   - Every module card should show progress and a quiet urgency signal in the same format.
3. Set up one shared visual system.
   - Lock spacing, typography, surfaces, and module visualization containers.
4. Add the AI orb and tiny assistant panel pattern.
   - Keep it input-first and always require approve/reject before writes.
5. Apply the shared template to the three priority depth modules.
   - Capital Core, Iron Temple, and Garage get hubs + internal tabs (scaffolding first).
6. Add the 4-second launch affirmation screen.
   - Include local fallback so it still works offline.
7. Rebalance the dashboard.
   - Ensure all modules are represented and progress appears before urgency lists.
8. Run one consistency pass.
   - Align CRUD/history/tags/filter/sort/undo behavior so modules feel like one system.
9. Do first full depth features in high-frequency modules.
   - Habit Stack, Task Protocol, Calendar, and Supply List stay first for real depth.

If you only do one thing each day, do the next unchecked step in this list.
