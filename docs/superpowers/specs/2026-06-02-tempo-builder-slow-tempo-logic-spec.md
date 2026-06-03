# Tempo Builder Slow Tempo Logic Spec

- Status: engineering-ready spec
- Scope: Garage module only
- Date: 2026-06-02
- Owner surface: Tempo Builder

## Purpose

Slow Tempo Logic is a training layer inside Tempo Builder that teaches a golfer to feel a slower swing rhythm through three clear landmarks:

1. Start
2. Top / Transition
3. Impact

Tempo Builder already has a premium rhythm-instrument direction, but the current training logic is too hidden in the live cockpit. The next pass should make the service immediately understandable as a calm golf rhythm cockpit: 60 BPM anchor beats, quiet 120 BPM guide ticks, a clear top/transition moment, and a clean impact landing.

This is not a new app module, generic metronome, soundboard, swing analyzer, or architecture rewrite. It is a Garage-local training model layered onto the existing Tempo Builder path.

## Current-State Findings

### Live UI Seam

- `GarageView.swift` owns the current Garage navigation stack.
- Garage Home launches Tempo Builder through `GarageNavigationDestination.tempoBuilder`.
- The active destination is `GarageTempoBuilderView()` in `HorizonVaultDialView.swift`.
- `GarageTempoWizard.swift` still exists, but it is not the routed live Tempo Builder surface in the current checkout.

### Current Cockpit Behavior

- `GarageTempoBuilderView` holds local state for:
  - `beatsPerMinute`, defaulting to 75
  - `ElasticSlingshotRecipe`
  - `ElasticSlingshotSoundProfile`
  - Engine Room sheet presentation
  - Swing Capture presentation
- The visible cockpit is currently dominated by:
  - top bar back/camera/settings controls
  - `HorizonVaultDialView` BPM dial
  - one play/stop control
- The main screen does not currently surface Start, Top/Transition, Impact, quiet subdivisions, or the "feel the top / do not rush down" coaching promise.

### Current Timing / Audio Concepts

- `ElasticSlingshotAudioEngine.swift` owns the active `AVAudioEngine` and `AVAudioSourceNode` synthesis path.
- `ElasticSlingshotRecipe` currently contains:
  - `tempoRatio`
  - `restInterval`
  - derived takeaway, pause, downswing, swing, and loop durations
- `ElasticSlingshotTempoRatio` currently offers:
  - `2.5:1`
  - `3:1`
  - `4:1`
  - fixed `pauseBeatCount` of `0.15`
  - fixed `downswingBeatCount` of `1`
- `ElasticSlingshotRenderState` drives sample rendering from one render configuration and resolves phases into:
  - takeback
  - pause
  - downswing
  - impact
  - loop delay
  - finished
- Sound skins are represented by `ElasticSlingshotSoundProfile` and share the same timing recipe.
- Preview and continuous playback already use the same render state with different playback modes.

### Current Settings Concepts

- `EngineRoomSettingsView.swift` is the current adjust surface.
- It controls:
  - ratio
  - sound skin
  - break between swings
  - selected-skin preview
- Settings are local SwiftUI state bindings from `GarageTempoBuilderView`.
- There is no SwiftData persistence for Tempo Builder settings in this path.
- Haptics are not currently surfaced in the live `GarageTempoBuilderView` / `EngineRoomSettingsView` seam.

### Existing Docs To Respect

- `docs/canonical/CANONICAL_PRODUCT_SPEC.md` defines Garage as owning Tempo Builder rhythm rehearsal and preserves local-first, module-scoped behavior.
- `docs/architecture/ARCHITECTURE.md` requires module boundaries, one shared shell, local-first persistence, and premium design-system-aligned surfaces.
- `docs/garage/GARAGE_REVAMP_BLUEPRINT.md` defines Tempo Builder as a Garage-local practice instrument with one stable timing engine and selectable premium sound skins.
- `docs/superpowers/specs/2026-05-30-tempo-builder-sound-skin-engine-design.md` defines sound skins as skins over the same tempo logic, not separate engines or separate timing systems.

### Reusable Pieces

- The current `AVAudioEngine` / `AVAudioSourceNode` synthesis path should be preserved.
- The existing recipe/render configuration pattern is the right place to derive training phases from one source of tempo truth.
- Existing phase concepts can map cleanly to training landmarks:
  - takeback begins at Start
  - pause/top maps to Top / Transition
  - impact maps to Impact
- The Engine Room sheet is a suitable home for advanced controls.
- The current sound-skin model can remain a timbre layer if Slow Tempo Logic becomes the training model above it.

### Risky Areas

- Adding separate Swift timers for UI landmarks could drift from audio.
- Treating 60/120 BPM logic as a second engine would violate the existing one-engine direction.
- Leaving ratio math as the main cockpit language would keep the training promise hidden.
- Making subdivisions too loud or too visually busy would turn the service into a generic metronome.
- Adding persisted settings would risk SwiftData migration work and is not needed for the first implementation.

### Unknowns

- The attached local screen recording is 17.54 seconds at 2940 x 1912, but this shell does not have `ffmpeg` / `ffprobe`, so the spec is based on repo inspection rather than frame-level video review.
- No Jam link, event stream, console logs, or recording metadata beyond local file metadata were available in this pass.
- Runtime audio feel still needs device/simulator listening validation in the implementation pass.

## Training Model

### Baseline

- Default anchor tempo: 60 BPM.
- Default subdivision: quiet 2x ticks at 120 BPM.
- Anchor beats define golf landmarks.
- Subdivision ticks are guide rails only.

### Landmark Map

| Beat | Label | Swing Meaning | Coaching Intent |
| --- | --- | --- | --- |
| 1 | Start | Begin takeaway | Start calm and committed. |
| 2 | Top / Transition | Arrive at top and feel spacing | Feel the top. Slight pause. |
| 3 | Impact | Strike lands cleanly | Down first, then speed. |

### Beat 2 Intent

Beat 2 must not feel like a tiny hidden pause. It should have enough audio and visual presence for the user to understand the top/transition moment without staring at advanced settings.

The top cue should communicate:

- Feel the top.
- Do not rush down.
- Down first, then speed.

### Impact Intent

Impact lands on Beat 3. It should feel bright, final, short, and distinct from both the anchor start and quiet subdivision ticks.

## User Experience

### Ready State

The ready state should make the training promise clear before the user presses play.

Primary visible hierarchy:

1. `60 BPM Swing Tempo`
2. `Start -> Top/Transition -> Impact`
3. `Quiet 120 BPM guide ticks`
4. `Feel the top. Do not rush down.`
5. Play action

The BPM dial can remain tactile, but it should no longer be the only meaningful cockpit content. Advanced settings should stay available through the existing settings/Engine Room path.

### Running State

The running state becomes the rhythm cockpit.

It should prioritize:

- current beat number
- current landmark label
- compact coaching cue
- strong anchor pulse on beats 1, 2, and 3
- quiet subdivision indication between anchors
- clear Beat 2 top/transition emphasis
- minimal controls: pause/stop and existing audio/settings access if needed

The user should not need to decode ratio math while practicing.

### Paused State

Paused should preserve the current training context:

- show the current or next landmark
- dim active pulse motion
- keep the primary action obvious
- avoid resetting the user's selected tempo/settings unless explicitly stopped

If the implementation keeps only play/stop at first, the paused state can be deferred. If pause is added, it must not create a second timing loop.

### Adjust / Settings State

Engine Room should remain the advanced surface.

Likely controls:

- anchor BPM, default 60
- subdivision mode:
  - off
  - quiet 2x, default
  - quiet 4x only if it proves useful
- training model / pack label, if multiple modes are later introduced
- sound skin
- impact tone / sound skin preview
- rest between swings
- ratio only if it still serves the Slow Tempo model

Engine Room can explain linked recipe details. The main cockpit should not become a settings dashboard.

## Audio Behavior

### Anchor Beats

- Anchor beats occur at 60 BPM by default.
- Beat 1, Beat 2, and Beat 3 are louder than subdivisions.
- Anchor beats should feel calm, premium, and golf-specific.
- Beat 1 should signal start without feeling like an alarm.
- Beat 2 should have more presence or tonal weight than a tiny pause.
- Beat 3 should resolve as a clean impact cue.

### Subdivision Ticks

- Subdivision ticks default to quiet 2x at 120 BPM.
- They should sit behind the anchors.
- They should guide spacing without becoming the main beat.
- They should be optional.
- They should not reuse the same loud transient as impact.

### Top / Transition Cue

- Beat 2 should be audible and visually obvious.
- The cue should support a slight pause and discourage rushing.
- The sound can be a held pressure, soft arrival, or restrained tonal lift, but not a novelty effect.

### Impact Cue

- Impact should be short, bright, and final.
- It should be distinct from anchor start and top.
- Existing impact synthesis and sound-skin impact parameters are reusable, but the implementation should make sure the impact lands on the Slow Tempo landmark rather than only at the end of hidden ratio math.

### Audio-Off Behavior

- If audio is off or unavailable, the visual landmark system should still teach the model.
- Audio startup failure must not block the Tempo Builder screen.
- The existing fail-soft audio posture should continue.

### Haptics

- Haptics are not currently exposed in the live Engine Room seam.
- If added later, they should mirror the same timing model:
  - stronger haptic for anchors
  - restrained or disabled haptic for subdivisions
  - distinct haptic at Beat 2 only if it helps training clarity
- Haptics should not introduce an independent timing loop.

## Visual Behavior

### Landmark Display

The main cockpit should show the three-landmark model directly:

- Start
- Top / Transition
- Impact

The current landmark should be visually dominant while running. The next landmark can be shown subtly.

### Beat Pulse

- Anchor beat pulse should be strong, restrained, and premium.
- Pulse should be driven from the same timing state as audio.
- Beat 2 pulse should have a visibly distinct treatment, such as a longer hold, brighter ring, or top marker emphasis.
- Impact pulse should feel final and crisp.

### Subdivision Indication

- Subdivisions should be visible as small guide ticks, not equal landmarks.
- They should be quieter in opacity, scale, and motion.
- They should be hideable through settings.

### What To Reduce Or Hide

Reduce on the main cockpit:

- ratio labels as primary language
- detailed recipe math
- full sound-skin browsing
- long instructional copy
- multiple secondary controls while running

Keep available behind Engine Room:

- ratio
- sound skin
- rest
- preview
- future subdivision mode
- future haptic control

## Settings Model

### Defaults

- Anchor BPM: 60
- Subdivision: quiet 2x / 120 BPM
- Landmarks: Start, Top / Transition, Impact
- Sound skin: preserve current default unless the implementation pass explicitly changes it
- Rest interval: preserve current default unless changed in a later approved pass

### User-Adjustable

For the first implementation, user-adjustable settings should be limited to:

- anchor BPM
- subdivision off/on quiet 2x
- sound skin
- rest between swings

The current ratio control may remain in Engine Room during the first pass, but the cockpit should not require the user to understand it.

### Advanced Settings

Belongs in Engine Room:

- ratio
- sound skin list
- sound preview
- rest interval
- subdivision mode
- future haptics
- future impact-tone details

Does not belong on the main cockpit:

- every recipe fraction
- every sound profile
- implementation labels like render mode or phase fractions
- long golf essays

## Implementation Plan

### Phase 1: Define One Training Timing Model

Files/areas:

- `ElasticSlingshotAudioEngine.swift`
- `HorizonVaultDialView.swift`
- `EngineRoomSettingsView.swift`

Create a Garage-local, non-persistent value model for Slow Tempo landmarks and subdivisions. It should derive anchor beat duration from `beatsPerMinute` and subdivision ticks from the same value.

Do not add SwiftData models.

### Phase 2: Align Audio Phases To Landmarks

Files/areas:

- `ElasticSlingshotRecipe`
- `ElasticSlingshotRenderConfiguration`
- `ElasticSlingshotRenderState.phase(for:configuration:)`
- existing sound profile synthesis helpers

Preserve one render path. Add or adapt phase information so Start, Top/Transition, subdivision ticks, and Impact are generated from one timing configuration.

Avoid a separate metronome engine.

### Phase 3: Build The Rhythm Cockpit UI

Files/areas:

- `GarageTempoBuilderView`
- local private subviews in `HorizonVaultDialView.swift`, or a new Garage-local file only if the view becomes too large

Add a compact cockpit that shows:

- 60 BPM Swing Tempo
- three landmark rail
- current beat/cue while running
- quiet subdivision hints
- existing play/stop behavior
- existing top bar affordances

Preserve routing through `GarageView.swift`.

### Phase 4: Move Advanced Controls Behind Engine Room

Files/areas:

- `EngineRoomSettingsView.swift`

Add subdivision mode only if Phase 1 needs a user-facing control. Keep ratio and sound skin secondary. Preserve preview behavior and non-persistent bindings.

### Phase 5: Verify Timing And Feel

Verification should include:

- `git diff --check`
- focused Swift parse/type checks for touched Garage files
- app build if the environment completes
- visual run of the live `.tempoBuilder` route
- audio listening check that confirms:
  - Beat 1 is Start
  - Beat 2 is Top / Transition
  - Beat 3 is Impact
  - subdivisions are quiet
  - sound skin changes do not change timing

## What Not To Touch

- Do not change SwiftData schemas.
- Do not add persistence for tempo settings without approval.
- Do not change app shell routing.
- Do not mutate non-Garage modules.
- Do not route through `GarageTempoWizard.swift` unless the live route is intentionally changed in a separate routing task.
- Do not add third-party audio dependencies.
- Do not add network audio generation.
- Do not turn Tempo Builder into a swing analyzer or real-time coaching guarantee.

## Risks

### Timing Drift

If visual pulses use SwiftUI timers while audio uses sample-frame timing, they can drift. The implementation should expose a single timing state or derive visual state from the same model used to schedule audio landmarks.

### Audio Latency

Anchor and impact cues must feel locked. The audio path should continue to use `AVAudioSourceNode` synthesis rather than delayed system sounds.

### UI Animation Mismatch

If the visual pulse is purely decorative, users may see one landmark while hearing another. Pulse timing must be treated as training information, not decoration.

### Too Many Controls

Adding subdivision, ratio, haptics, sound skin, rest, and impact settings to the main screen would weaken the cockpit. Main screen controls should stay minimal.

### Hidden Training Logic

The current problem can return if the UI only shows BPM and hides the Start / Top / Impact model behind settings. The main screen must carry the training promise.

## Acceptance Criteria

- User can understand the 3-beat model immediately from the ready screen.
- Ready state clearly communicates `60 BPM Swing Tempo`.
- Ready state clearly communicates `Start -> Top/Transition -> Impact`.
- Ready state clearly communicates quiet 120 BPM guide ticks.
- Running state shows the current beat number and swing cue.
- 60 BPM anchors are louder than subdivisions.
- 120 BPM subdivisions are quiet and optional.
- Beat 2 / Top is visually and audibly obvious.
- Impact cue feels distinct, bright, short, and final.
- Audio and visual landmarks are driven by one timing model.
- Sound skins remain skins over the same timing logic.
- Advanced controls remain secondary.
- No SwiftData migration is introduced.
- No non-Garage scope creep is introduced.
- No navigation architecture rewrite is introduced.
