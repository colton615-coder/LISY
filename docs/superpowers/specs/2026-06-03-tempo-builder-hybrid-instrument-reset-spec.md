# Tempo Builder Hybrid Instrument Reset Spec

- Status: user-direction captured; ready for review
- Scope: Garage module only
- Date: 2026-06-03
- Owner surface: Tempo Builder
- Source feedback: user hated the current pass broadly; primary failure was that sound and visuals do not connect

## Purpose

Reset Tempo Builder around a hybrid premium instrument: keep the circular cockpit direction, but make Start, Load, and Impact the dominant experience instead of BPM math or ratio controls.

The current screen has usable energy, but it risks feeling like a neon metronome HUD. The next pass should feel like a sharp, athletic, tactile golf training instrument. It should communicate calm timing and precision without asking the user to decode `3:1` or `4:1` while practicing.

This spec is not a new app module, routing change, persistence project, App Intents project, or audio dependency change. It is a Garage-local correction to Tempo Builder's product language, cockpit hierarchy, and audio/visual synchronization.

## Current Product Diagnosis

### What Is Broken

- Too many things compete at once: BPM, play/stop, nodes, arc, status badge, controls, legend, camera, settings, and sound skin.
- Ratio language is too exposed and too technical for the main practice surface.
- The circular cockpit reads too much like a clock/metronome instead of a golf swing instrument.
- The visual phase system and audio system are not being treated as one locked training signal.
- Color is exciting, but the current neon treatment can drift toy-like if it is not constrained by phase state.
- The screen has direction, but not enough luxury restraint or live-use clarity.

### What To Keep

- Keep the circular cockpit foundation.
- Keep Start, Top / Transition, and Impact visible.
- Keep the camera and settings affordances.
- Keep the bottom micro-map, but make it quieter.
- Keep green and yellow as phase colors, but refine them into premium active-state cues.
- Keep a strong central instrument rather than replacing the screen with a settings dashboard.

### What To Kill Or Demote

- Kill raw ratio language on the main cockpit.
- Demote BPM as a technical number; keep it as the tempo anchor, not the product identity.
- Demote visible tuning controls while running.
- Kill any visual pulse that is decorative rather than tied to audible timing.
- Kill any sound skin behavior where visual timing and audible landmarks feel unrelated.

## Product Direction

### Target Feel

Tempo Builder should feel like:

- a premium training instrument
- sharp and athletic
- tactile and luxury
- calm enough to practice with
- precise enough to trust

It should not feel like:

- a generic metronome
- a soundboard
- a neon game HUD
- a science panel
- a swing analyzer
- a toy rhythm app

### Experience Model

The user should understand the loop immediately:

1. Start
2. Load
3. Impact

`Top / Transition` remains valid golf language, but the cockpit should use `Load` as the primary short label when space or clarity matters. `Top / Transition` can appear as the secondary label or accessibility/detail copy.

The main promise is:

> Hear it. See it. Repeat it.

Do not ship that as visible marketing copy unless needed. It is the design principle for the pass.

## Ratio Decision

### Verdict

Raw `2.5:1`, `3:1`, and `4:1` labels should not appear on the main Tempo Builder cockpit.

They are useful engine concepts, but confusing live-practice language. The user should not have to understand backswing-to-downswing math to use the instrument.

### Product Names

Replace main-facing ratio language with swing-shape presets:

| Engine Ratio | Main-Facing Label | Feel Line |
| --- | --- | --- |
| `2.5:1` | Athletic | Quicker load. Crisp release. |
| `3:1` | Balanced | Classic load. Clean transition. |
| `4:1` | Stretched | Longer load. More patience at the top. |

### Where Ratio Can Still Exist

Raw ratio numbers may remain only in Engine Room as advanced detail.

Recommended Engine Room presentation:

- Primary selector labels: `Athletic`, `Balanced`, `Stretched`
- Secondary metadata: `2.5:1`, `3:1`, `4:1`
- Section title: `Swing Shape`, not `Ratio Tuner`
- Optional helper line: `Controls how long the load feels before release.`

### Main Cockpit Language

The main cockpit should say something closer to:

- `Balanced Swing Shape`
- `60 BPM anchor`
- `Start -> Load -> Impact`

Avoid:

- `Ratio Tuner`
- `3:1`
- `linked recipe`
- recipe math as primary display

## Hybrid Instrument Design

### Recommended Approach

Use the current circular cockpit as the container, but change what it means.

The circle is not a timer. It is a swing phase instrument.

It should show:

- three landmark nodes
- a restrained phase path
- center state for the current landmark
- subtle guide ticks
- phase-locked pulse states
- one dominant play/stop action

### Ready State

Primary hierarchy:

1. Swing shape label, such as `Balanced Swing Shape`
2. Tempo anchor, such as `60 BPM anchor`
3. Phase map: `Start -> Load -> Impact`
4. Selected sound skin, quiet but visible
5. Play action

The ready state should not be a settings preview. It should make the practice model obvious before the first tap.

### Running State

Primary hierarchy:

1. Current phase label
2. Current beat or landmark number
3. Phase-locked pulse animation
4. Quiet guide ticks
5. Stop action

The user should be able to glance once, then practice mostly by sound.

### Color Rules

Green and yellow can stay, but they must be disciplined.

- Green: Start, ready, active path, calm precision
- Yellow: Load / top emphasis
- Impact: brief bright accent, not a permanent glow flood
- Inactive nodes: dark glass, low-opacity edge strokes
- Subdivision ticks: quiet, not equal to landmarks

No broad neon wash should dominate the whole screen while all phases are inactive.

### Motion Rules

- Pulse motion must correspond to audio landmarks.
- Beat 2 / Load should have a controlled hold or pressure effect.
- Impact should be short, crisp, and final.
- Reduced Motion must preserve phase clarity without relying on large animation.
- Default animation should stay near `.spring(response: 0.35, dampingFraction: 0.8)`.

## Audio / Visual Lock Contract

This is the most important acceptance gate.

The visual instrument must not be decorative. Every visible phase state must correspond to the same timing model that drives audio.

### Required Lock Points

- Start visual pulse aligns with Start sound.
- Load visual pulse aligns with top / transition sound.
- Impact visual pulse aligns with impact transient.
- Quiet guide ticks are visually smaller and audibly quieter.
- Sound skin changes alter timbre, not timing.
- Tempo changes update both audio and visual timing immediately.
- Swing shape changes update both audio and visual phase spacing immediately.

### Failure Definition

The pass fails if the user can say:

- the sound and visuals feel disconnected
- the screen says one phase while the audio implies another
- changing swing shape does not produce a perceptible difference
- the screen feels like a metronome with golf words pasted on

## UI Scope

### Main Cockpit

Keep:

- Back control
- Camera control
- Settings control
- selected sound skin
- Start / Load / Impact phase model
- central circular instrument
- one dominant play/stop action
- quiet bottom micro-map

Change:

- Make swing shape more meaningful than raw ratio.
- Make phase label more meaningful than BPM number while running.
- Make controls quieter while playback is active.
- Make the bottom legend visually quieter.
- Make selected sound skin feel integrated, not like a random badge.
- During playback, hide or visually mute all tuning controls except Stop, camera/settings access, and the active phase instrument.
- BPM adjustment belongs in Engine Room or as a tiny ready-state-only control. Kill visible `+` / `-` controls during running.

### Engine Room

Rename and restructure advanced controls:

- `Ratio Tuner` becomes `Swing Shape`
- `2.5:1 / 3:1 / 4:1` become secondary details under `Athletic / Balanced / Stretched`
- `Linked recipe` should not be the emotional lead
- Sound skin stays in Engine Room
- Break between swings stays in Engine Room
- Preview behavior remains explicit, not autoplay

## Architecture Boundaries

Allowed:

- Garage-local UI changes in the live Tempo Builder seam
- Garage-local value-model naming around swing shape
- Garage-local audio/render timing alignment
- Engine Room copy and hierarchy changes
- In-memory state only
- Existing `AVAudioEngine` / `AVAudioSourceNode` path

Not allowed:

- SwiftData migration
- new persistence for Tempo Builder settings
- routing through `GarageTempoWizard.swift`
- changes outside Garage
- new third-party dependencies
- network audio generation
- App Intents work in this pass
- changing sound skins into separate engines
- making Tempo Builder a real-time swing analyzer

## Implementation Procedure

### Phase 1: Live Route And Current-State Audit

Verify the live route before editing.

Expected route:

- `GarageView.swift`
- `GarageNavigationDestination.tempoBuilder`
- `GarageTempoBuilderView()` in `HorizonVaultDialView.swift`

Do not edit `GarageTempoWizard.swift` unless route ownership has intentionally changed.

Audit:

- `HorizonVaultDialView.swift`
- `EngineRoomSettingsView.swift`
- `ElasticSlingshotAudioEngine.swift`
- `ElasticSlingshotRecipe`
- `ElasticSlingshotTempoRatio`
- `GarageSlowTempoLogic`

### Phase 2: Rename Product Language Without Changing Timing Semantics

Create or adapt a Garage-local display mapping:

- `2.5:1` -> `Athletic`
- `3:1` -> `Balanced`
- `4:1` -> `Stretched`

Keep existing engine math intact unless timing behavior is already wrong.

Main cockpit should use swing-shape language.

Engine Room may show raw ratios as secondary metadata.

### Phase 3: Reframe The Cockpit Around The Hybrid Instrument

Update `GarageTempoBuilderView` and local private subviews so the visual hierarchy becomes:

1. selected swing shape and tempo anchor
2. Start / Load / Impact map
3. circular phase instrument
4. dominant play/stop control
5. quiet secondary controls

Preserve camera/settings access.

### Phase 4: Lock Visual State To Audio Timing

Ensure visual phase state is derived from the same timing model as audio playback.

If the current visual state uses elapsed wall-clock time while audio uses sample-frame render state, the implementation must reduce drift risk by deriving both from one shared recipe/logic model and by updating both together when BPM, sound skin, or swing shape changes.

Do not let SwiftUI own the truth. SwiftUI may display phase state, but the recipe/timing model must be the single source used by both render timing and visual phase calculation.

Do not add a second metronome timer.

### Phase 5: Make Swing Shape Audibly And Visually Perceptible

Changing `Athletic`, `Balanced`, or `Stretched` must create a perceptible difference:

- different time to Load
- different pressure/hold at Load
- different visual path pacing
- same final Impact clarity

If a user cannot perceive the difference, the implementation is not done.

### Phase 6: Refine Engine Room

Change Engine Room from technical recipe panel to advanced instrument setup.

Required updates:

- `Ratio Tuner` -> `Swing Shape`
- primary labels use `Athletic`, `Balanced`, `Stretched`
- raw ratio appears only as small secondary text, if shown
- sound skin selector remains explicit
- preview remains explicit
- break between swings remains available

### Phase 7: Verify

Required verification:

- `git diff --check`
- focused Swift parse/type checks for touched Garage files
- full build if the environment completes
- visual run of live `.tempoBuilder`
- audio listening check

Audio/visual listening checklist:

- Start cue is visibly and audibly aligned.
- Load cue is visibly and audibly aligned.
- Impact cue is visibly and audibly aligned.
- Guide ticks are quieter than landmarks.
- Impact is distinct from guide ticks.
- Athletic / Balanced / Stretched are perceptibly different.
- Sound skin changes do not change timing.
- Stop resets cleanly.
- Camera and settings still open.

## Acceptance Criteria

- Main cockpit no longer exposes raw ratio math as primary language.
- User can understand Start -> Load -> Impact immediately.
- The circular instrument reads as a swing phase instrument, not a generic clock.
- The selected swing shape is visible and understandable.
- The selected sound skin is visible but not dominant.
- Playback has one obvious dominant action.
- Camera and settings remain accessible.
- Bottom micro-map is quieter and does not compete with the main instrument.
- Green/yellow phase colors feel premium, not toy-like.
- Audio and visual timing are perceptibly locked.
- Swing shape changes are perceptibly different.
- No SwiftData migration is introduced.
- No non-Garage module changes are introduced.
- No App Intents work is introduced.
- No new audio dependency is introduced.

## Review Notes

This spec intentionally tightens the previous slow-tempo direction. The previous direction was broadly correct, but this reset makes three decisions explicit:

1. The cockpit is a hybrid swing instrument, not a BPM clock.
2. Ratio math is advanced engine detail, not live-practice language.
3. Audio/visual lock is the primary success criterion, not decorative polish.
