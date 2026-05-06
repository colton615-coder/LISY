# Garage Revamp Blueprint

- Status: active Garage refactor blueprint
- Scope: Garage module only
- First pass: oversized swipe-card Home and primary navigation shells
- Last updated: 2026-05-06

## Purpose

Revamp Garage into a cleaner, calmer, more intentional golf-practice flow without deleting the premium practice work already built.

Garage Home is organized around one oversized swipeable card at a time:

1. Drill Plans
2. Tempo Builder
3. Journal

The module should feel like a premium golf practice command center, not a stacked dashboard, internal tab bar, or dense widget pile.

## Product Rules

- Garage Home uses a horizontally swipeable oversized card deck.
- The visible Home choices are Drill Plans, Tempo Builder, and Journal.
- Drill Plans starts with the environment decision: Net, Range, Putting Green.
- Tempo Builder starts as a standalone rhythm tool shell.
- Journal starts as a golf memory system shell.
- Existing Garage practice systems stay preserved unless a later approved pass removes or replaces them.

## Drill Plans Flow

Environment choices:

- Net
- Range
- Putting Green

Each environment opens an Environment Drill Plans screen with three choices:

- Saved Routines
- Generate New Routine
- Build My Own

Saved Routines filters real persisted `PracticeTemplate` rows by selected `PracticeEnvironment`.

If no saved routines exist, use:

> No saved routines for this environment yet.

Secondary copy:

> Generate a new routine or build your own to start creating repeatable practice plans.

Generate New Routine uses the existing local, reviewable Garage planner path. It must not introduce fake-precision AI language, network dependence, or silent writes.

Build My Own uses the existing manual routine builder and keeps the underlying `PracticeTemplate` model intact.

## Preservation Rules

Preserve:

- `GarageDrillDictionary`
- `PracticeTemplate`
- `PracticeSessionRecord`
- `GarageActiveSessionView`
- Focus Room components
- Vault and session history
- Local coach planner
- Template/routine builder
- Session detail and review logic
- GaragePro styling primitives
- Existing environment metadata

Do not introduce:

- SwiftData migration
- model renames
- third-party dependencies
- unrelated module changes
- global app navigation changes
- fully built Tempo Builder service
- Journal persistence before approval

## First-Pass Acceptance Criteria

- Garage Home shows one oversized swipeable card at a time.
- Cards are horizontally swipeable with a clear page indicator.
- Home cards are Drill Plans, Tempo Builder, and Journal.
- The internal Garage bottom tab bar is not present in the new Home flow.
- Drill Plans card contains Net, Range, and Putting Green.
- Each environment opens its Environment Drill Plans screen.
- Each Environment Drill Plans screen contains Saved Routines, Generate New Routine, and Build My Own.
- Tempo Builder Start opens a clean Tempo Builder screen.
- Journal New Entry and Archive open clean Journal screens.
- No SwiftData migration is introduced.
- Existing Garage premium code remains available for future passes.
