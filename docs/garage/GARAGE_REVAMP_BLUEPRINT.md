# Garage Revamp Blueprint

- Status: active Garage refactor blueprint
- Scope: Garage module only
- First pass: oversized swipe-card Home and primary navigation shells
- Last updated: 2026-05-30

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
- Tempo Builder is a standalone rhythm rehearsal service with one stable timing engine and selectable premium sound skins.
- Journal starts as a golf memory system shell.
- Existing Garage practice systems stay preserved unless a later approved pass removes or replaces them.

## Tempo Builder Flow

Tempo Builder is a Garage-local practice instrument, not a generic metronome and not a swing-analysis replacement.

Core contract:

- The timing engine stays singular and stable across all sound packs.
- BPM, ratio, pause, setup delay, loop timing, and fine-tuning logic behave identically no matter which sound pack is selected.
- Sound packs are skins over the same tempo logic, not separate training modes.
- Every sound pack follows the same full swing shape: takeaway load, top tension, soft downswing trail, bright impact snap.
- The audio priority is coachable first, premium second, fun third.
- Sound pack selection is available from the main cockpit through a compact one-tap selector sheet.
- Browsing sound packs does not autoplay. Each pack exposes an explicit preview action.
- Pack descriptions use one short plain-English feel line.

Initial sound-pack direction:

- Elastic: smooth stretch, calm release, sharp snap.
- Storm: low pressure build, thunder body, bright strike.
- Airframe: breathy lift, clean trail, crisp snap.
- Reed: controlled reed texture with playful edge, not cheap novelty.
- Pulse: modern rhythm pressure with surgical impact.
- Gravity: deep load, soft fall, bright strike.
- Glass: clean shimmer, tight top, precise snap.
- Rubber: elastic training feel without toy energy.

Do not turn this into:

- a separate tempo engine per pack
- a noisy soundboard
- a preset system that changes the user's timing logic
- hidden persistence or SwiftData schema work
- real-time swing coaching claims

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
- Tempo Builder routing and local-only service boundary

Do not introduce:

- SwiftData migration
- model renames
- third-party dependencies
- unrelated module changes
- global app navigation changes
- Tempo Builder SwiftData migration without explicit approval
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
- Tempo Builder keeps one timing/fine-tuning model while allowing multiple premium sound skins.
- Journal New Entry and Archive open clean Journal screens.
- No SwiftData migration is introduced.
- Existing Garage premium code remains available for future passes.
