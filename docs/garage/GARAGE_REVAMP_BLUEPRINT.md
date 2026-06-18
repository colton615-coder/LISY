# Garage Revamp Blueprint

- Status: active Garage blueprint; Tempo Builder direction refreshed 2026-06-17
- Scope: Garage module only
- First pass: oversized swipe-card Home and primary navigation shells
- Last updated: 2026-06-17

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
- Tempo Builder is a standalone rhythm rehearsal service with separate Guided Swing and steady-click Metronome modes.
- Journal starts as a golf memory system shell.
- Existing Garage practice systems stay preserved unless a later approved pass removes or replaces them.

## Tempo Builder Flow

Tempo Builder is a Garage-local practice instrument, not a swing-analysis replacement. Guided Swing is the premium swing-rhythm trainer; Metronome is the separate steady-click trainer.

Core contract:

- Guided Swing and Metronome retain separate saved BPM values and do not silently synchronize.
- Control Room remains a shared tuning pattern, with rows that change for the active mode.
- Metronome stays one steady click per beat. It is not a fixed Start / Top / Impact golf cycle.
- Guided Swing uses a Sport-Tech + Luxury direction: precise, athletic, polished, and restrained.
- The swing arc is the timing authority for Guided Swing. Audio follows the arc rather than driving an independent approximation.
- Guided Swing audio targets `smooth load -> clean transition -> crisp strike`.
- Address uses a soft start marker.
- Backswing uses a noticeable but restrained synthesized rising/load texture.
- Top uses a polished or imported local clean transition cue.
- Downswing uses a synthesized quick acceleration/release texture.
- Impact uses a polished or imported local crisp premium strike.
- Synthesized audio owns continuous motion texture because it must follow arc timing precisely.
- Polished or imported local assets may own landmark cues such as Top and Impact.
- This audio direction is an approved implementation target, not a claim that final synchronization, assets, or listening QA are complete.
- Main practice surfaces stay focused on active mode, BPM, Start/Stop, rhythm visual, and tuning access.

Do not turn this into:

- a noisy soundboard
- one shared timing behavior or saved BPM across both modes
- a fixed `3:1` Start / silent Top / Impact Metronome cycle
- an eight-skin or six-identity expansion target
- generated-only audio that forbids polished local landmark assets
- audio-led visual timing
- a neon cockpit, physical-metronome centerpiece, or gamer dashboard
- maximum-impact sound design that accepts listening fatigue
- speculative calibration, spoken detection, or swing-recognition work
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
- Tempo Builder keeps Guided Swing and steady-click Metronome behavior distinct, retains separate BPM memory, and uses the shared mode-aware Control Room pattern.
- Journal New Entry and Archive open clean Journal screens.
- No SwiftData migration is introduced.
- Existing Garage premium code remains available for future passes.
