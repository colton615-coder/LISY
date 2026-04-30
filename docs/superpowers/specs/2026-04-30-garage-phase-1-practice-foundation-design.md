# Garage Phase 1 Practice Foundation Design

- Status: approved
- Scope: Garage practice foundation only
- Authoritative for: the Phase 1 Garage practice workflow layered onto the current module
- Does not change: canonical Garage analysis ownership, shared shell structure, shared design-system authority, or existing Garage review/analysis surfaces
- Date: 2026-04-30

## Goal

Turn the two external Gemini drafts into one repo-native Garage Phase 1 spec that matches LIFE IN SYNC's current product and architecture truth.

The key user outcome is:
- the user enters Garage through a real practice environment
- the user starts a template-backed practice session
- the user completes drills at their own pace
- the user adds drill notes as needed
- the user ends the session intentionally
- the user saves one overall quality score and optional end-of-session feel note

This is a practice-system foundation, not a Garage identity replacement.

## Current Truth

Garage already exists in this repo as more than a blank concept.

Today:
- `GarageView` already routes through `PracticeEnvironment`
- `GarageTemplateBuilderWizard` already owns template authoring from a reusable drill dictionary
- `GarageActiveSessionView` already owns local active-session execution with drill completion and per-drill notes
- `PracticeSessionRecord` already persists end-of-session history
- canonical docs still define Garage as analysis-first at the module level

This creates an important constraint:
- the new practice workflow must fit inside Garage
- it must not claim to replace measured analysis as the module's canonical foundation
- it must not reopen architecture that has already been locked down in the canonical docs

## Problem

The two Gemini documents contain strong product instincts, but they are unsafe as direct implementation sources.

Useful material:
- premium, tactile Garage tone
- manual pacing instead of auto-advance
- environment-aware practice entry
- feel-first coaching language instead of fake biomechanical certainty

Conflicting material:
- treating Garage as if analysis no longer exists
- proposing a broad Phase 1 code/document purge as a prerequisite for forward motion
- inventing hard visual laws outside `ModuleTheme` and `AppModule.garage`
- introducing a new top-level `GarageSessionStore` as if current Garage seams do not already exist
- implying future control patterns as immediate Phase 1 requirements

The repo needs one clean Phase 1 definition that keeps the good instincts and removes the conflicts.

## Approved Direction

Phase 1 adds a structured practice foundation inside Garage while preserving the existing analysis identity and architecture boundaries.

This means:
- Garage now has two coexisting layers:
  - the existing analysis/review layer
  - the new structured practice workflow
- Phase 1 is the first buildable practice slice, not a docs-only cleanup pass
- the earlier "purge" language is reinterpreted as documentation reconciliation only
- the current practice seams remain the implementation foundation unless a later approved spec replaces them

## Canonical Product Positioning

Garage remains the home of measured swing analysis, checkpoint review, overlays, notes, coaching presentation, and history.

Garage also now owns structured golf-practice workflows that are useful even when a user is not actively using the analysis pipeline.

The relationship should remain strict:
- analysis owns measured evidence
- practice owns routines, execution, session completion, and subjective quality logging
- AI language may help translate or guide, but it must not overstate certainty or silently write user data

This Phase 1 spec does not authorize rewriting the canonical product spec or architecture doc. It is additive and subordinate to both.

## Phase 1 User Flow

### Entry

The user enters Garage and chooses a `PracticeEnvironment`.

Phase 1 uses the existing environment split:
- `net`
- `range`
- `puttingGreen`

The environment choice is not decorative. It determines which templates are visible and frames the kind of practice the user is about to do.

### Authoring

The user can create or reuse a practice template through the existing Garage authoring flow.

Phase 1 keeps these foundations:
- `PracticeDrillDefinition` as the global reusable drill dictionary entry
- `PracticeTemplate` as the persisted template
- `PracticeTemplateDrill` as the stable ordered drill snapshot inside a template

The current three-step builder shape remains valid:
1. setup
2. dictionary selection or creation
3. review and save

### Active Session

Starting a template creates an `ActivePracticeSession`.

Phase 1 keeps the session loop intentionally restrained:
- drill completion is managed in local session state
- per-drill notes remain available during execution
- the user controls pacing manually
- no auto-advance, countdown timers, or forced routing events occur during the session

The session should feel deliberate, not theatrical.

### Session Completion

Ending a session is an intentional action, not an automatic side effect.

At session end, Garage captures:
- one overall session `qualityScore`
- one optional end-of-session feel note
- the existing completion summary and aggregated drill notes

The score is session-level for Phase 1. It is not per-rep and not per-drill-block in this first slice.

### Persistence

Active execution state remains local during the session.

Persistence occurs when the user completes the session.

`PracticeSessionRecord` remains the persisted end-of-session ledger model and should be extended in the Phase 1 implementation to support:
- `qualityScore: Int?`
- `sessionFeelNote: String`

The quality score must be bounded to the user-facing 1 through 10 scale in implementation.

## Interface And Type Contract

Phase 1 builds on the current Garage practice seams. It does not replace them with parallel abstractions.

Keep as the Phase 1 foundation:
- `PracticeEnvironment`
- `PracticeDrillDefinition`
- `PracticeTemplate`
- `PracticeTemplateDrill`
- `ActivePracticeSession`
- `PracticeSessionRecord`
- `GarageView`
- `GarageTemplateBuilderWizard`
- `GarageActiveSessionView`

Do not introduce:
- a new top-level `GarageSessionStore` as the primary source of truth
- a separate practice architecture that bypasses the current module seams
- a global environment object blob for practice session state

Preferred ownership:
- `GarageView` owns environment entry and routing
- `GarageTemplateBuilderWizard` owns authoring
- `GarageActiveSessionView` owns in-session execution
- `PracticeSessionRecord` owns persisted session history payload

## UX And Tone Rules

Phase 1 should preserve the strongest emotional insight from the Gemini drafts without violating the app's actual design system.

Keep:
- premium, tactile Garage atmosphere
- feel-first instructional language
- self-paced flow
- one-handed mobile awareness where useful

Do not canonize:
- hardcoded `#050505` as a Garage law
- forced ignoring of system appearance as a blanket rule
- bottom-right-only interaction targets as a universal requirement
- fixed visual constants that bypass `ModuleTheme` and `AppModule.garage`

Visual authority remains:
- shared theme tokens
- `ModuleTheme`
- `AppModule.garage`
- existing shared Garage-owned chrome helpers where applicable

The Garage mood may be distinct, but it must still belong to the app.

## Explicit Non-Goals

Phase 1 does not include:
- a full Garage identity pivot away from analysis
- deletion of analysis or review surfaces
- a broad repo purge of old Garage code
- a custom magnetic score slider
- gloved-thumb physical-control engineering as a hard requirement
- Shatter Intervention routing or failure-branch choreography
- rep-level scoring
- unsupported biomechanics claims or fake diagnostic precision

## Later-Phase Parking Lot

The following ideas are valid future candidates, but they are not required for Phase 1:
- a custom tactile session-quality input control
- stronger premium physicality in the end-of-session scoring interaction
- remedial branching logic after poor session quality
- deeper environment-specific flows
- more opinionated coaching copy tied to session patterns

Those later phases must still respect canonical product truth and the shared design system.

## Verification

### Spec Acceptance

Confirm that the spec:
- does not conflict with `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
- does not conflict with `docs/architecture/ARCHITECTURE.md`
- does not claim Garage analysis has been removed or demoted from module truth
- does not introduce design-law drift outside the existing app system

### Product-Slice Acceptance

Phase 1 is successful when:
- a user can choose an environment
- a user can build or select a template
- a user can start a template-backed active session
- a user can complete drills and add drill notes
- a user can end the session intentionally
- Garage saves one overall quality score plus an optional end-of-session feel note with the session record

### Implementation Verification

When the implementation phase begins, run:

```sh
git diff --check
xcodebuild -scheme LIFE-IN-SYNC -destination 'generic/platform=iOS Simulator' build
```

Implementation should also verify that any SwiftData schema/version changes required by the `PracticeSessionRecord` extension are coordinated cleanly with app and preview containers.

## Self-Review

This spec collapses the two Gemini documents into one repo-native design artifact.

This spec preserves the useful ideas from those drafts without letting them override canonical product and architecture truth.

This spec defines Phase 1 concretely as the first real Garage practice slice.

This spec leaves no ambiguity about the session score location: it is session-level in Phase 1.
