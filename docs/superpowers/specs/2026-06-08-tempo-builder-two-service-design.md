# Tempo Builder Two-Service Design

- Status: awaiting user review
- Scope: Garage module only
- Date: 2026-06-08
- Owner surface: live Garage Tempo Builder
- Product input: screen-recording audit and completed Grill Me questionnaire

## Objective

Tempo Builder becomes a focused two-service training tool:

1. `Guided Swing` is the default premium rhythm trainer.
2. `Metronome` is a secondary steady-click trainer.

Each service owns its own saved BPM and running behavior. The shared experience remains direct: set tempo, press Start, follow the rhythm, swing.

## Source-Of-Truth Alignment

This design follows:

- `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
  - Garage owns Tempo Builder rhythm rehearsal.
  - Flagship surfaces remain dark, tactile, premium, local-first, and offline-first.
- `docs/architecture/ARCHITECTURE.md`
  - Tempo Builder remains a Garage-local detail flow.
  - No shell, cross-module, third-party, or SwiftData changes are required.
- Existing live route:
  - `GarageView.swift -> GarageNavigationDestination.tempoBuilder -> GarageTempoBuilderView()`

The questionnaire's latest explicit direction supersedes the older one-personal-tempo product plan. Guided Swing and Metronome now intentionally retain separate saved BPM values.

## Current Live Implementation

The active implementation already has useful foundations:

- `HorizonVaultDialView.swift` owns the live two-page Tempo Builder UI.
- `ElasticSlingshotAudioEngine.swift` owns generated real-time audio, continuous playback, and one-cycle preview.
- `GarageSlowTempoLogic.swift` supplies Guided Swing visual timing.
- `GarageHomeTabView.swift` owns the Garage Home Tempo Builder preview.

Current conflicts to remove:

- Garage Home hardcodes `60 BPM`.
- Guided Swing and Metronome share `garage.tempoBuilder.bpm`.
- Metronome appears before Guided Swing in page ordering.
- Guided Swing still supports background clicks.
- Guided Swing uses the J-arc.
- Main pages expose sound selection.
- Metronome's BPM slider is disabled while running.
- The current primary button only supports Start/Stop, not Pause/Resume/Stop.
- Control Room is a partial-height sheet with shared rows.
- Running engine updates currently reset timing immediately rather than at the next complete cycle boundary.

## Locked Product Decisions

### Shared

- Guided Swing is the first and default page.
- The user can swipe once between Guided Swing and Metronome.
- Each page displays only its own BPM.
- BPM adjustments auto-save locally and show a brief `Tempo saved` toast.
- The BPM slider remains visible and editable before and during playback.
- Start remains the dominant action.
- Pause, Resume, and Stop are available while running.
- Stop returns immediately to the ready state without a summary or save prompt.
- One shared Control Room entry point opens a full-screen Garage-local page.
- Control Room rows change according to the active service.
- Full Swing, Short Game, Putting, ratio, and club profile controls do not appear.

### Guided Swing

- Guided Swing uses a thin horizontal Start -> Top -> Impact timeline.
- A glowing marker follows shared recipe timing.
- Impact receives a restrained pulse/flash.
- Guided Swing uses a continuous generated build that climaxes into impact.
- Guided Swing has no background clicks.
- Start and Resume use three clean audio ticks before the first build begins.
- The three-tick cue is audio-first because the golfer may be looking at the ball. It does not add a setup screen or spoken coaching.

### Metronome

- Metronome starts and resumes immediately.
- Metronome plays one steady click per beat.
- It has no count-in, accents, subdivisions, build sound, impact crash, or public click-sound picker.
- Its main visual is a classic restrained pendulum.

## Persistence And Compatibility

No SwiftData schema or migration is required. Continue using `@AppStorage`.

### Keys

- Guided Swing BPM keeps the existing key:
  - `garage.tempoBuilder.bpm`
  - Reason: preserves the user's current saved tempo and fixes Garage Home readback without losing data.
- Metronome adds:
  - `garage.tempoBuilder.metronomeBPM`
  - Default: `60`
- Guided Swing sound keeps:
  - `garage.tempoBuilder.guidedSound`
- Guided Swing rest interval keeps:
  - `garage.tempoBuilder.restInterval`
- Haptics adds one shared preference:
  - `garage.tempoBuilder.haptics`
  - Default: enabled

The obsolete `garage.tempoBuilder.guidedClicks` value may remain stored for compatibility, but no live UI or playback path reads it.

## Screen Design

### Garage Home Preview

- Read `garage.tempoBuilder.bpm` instead of hardcoding `60`.
- Present the value as the saved Guided Swing BPM because Guided Swing is the primary service.
- Replace ambiguous mode chips with a clear primary readback:
  - `Guided Swing`
  - `Saved swing tempo`
- Keep one dominant Start action.
- Keep the current Garage card architecture and premium styling.

### Tempo Builder Shell

- Keep the current Garage-local top bar and swipeable `TabView`.
- Page order is `Guided Swing`, then `Metronome`.
- Use a compact segmented/page indicator that clearly communicates the active service.
- Keep Swing Capture secondary.
- Control Room opens full-screen and receives the active service.
- Switching pages immediately stops active playback and returns both services to ready state.

### Guided Swing Ready State

Hierarchy:

1. `Guided Swing`
2. `Set your swing tempo. Press Start and follow the build to impact.`
3. prominent saved BPM
4. horizontal BPM slider
5. thin Start / Top / Impact timeline
6. dominant Start button
7. Control Room access in the top bar

Do not show Sound Style, rest timing, Preview Guided Swing, background clicks, or profiles on the main screen.

### Guided Swing Running State

- Keep the BPM readout and slider visible.
- Show Pause and Stop as separate actions.
- Timeline marker follows the currently applied playback BPM, not an uncommitted slider value.
- Slider changes auto-save immediately but show `Applies next swing` until the next cycle boundary.
- At the next full-cycle boundary, audio and timeline timing adopt the new BPM together.
- Pause immediately silences audio, cancels pending haptics, and resets the marker to Start.
- Resume begins a fresh three-tick cue, then starts a new full swing cycle.
- Stop immediately silences audio and returns to ready state.

### Guided Swing Timeline

- Thin horizontal base line with Start, Top, and Impact landmarks only.
- Start-to-Top occupies the larger visual/time portion.
- Top-to-Impact occupies the shorter, faster portion.
- The moving marker uses the same recipe timing as generated audio.
- During rest, the marker returns to Start and waits there.
- Impact uses a short gold pulse and restrained glow.
- Reduce Motion keeps landmark state changes but removes traveling/glow animation.

### Metronome Ready And Running States

- Title: `Metronome`
- Support: `Steady click training.`
- Show its own saved BPM and horizontal slider.
- Use the existing pendulum direction, simplified so it reads as a classic metronome.
- Start begins steady clicks immediately.
- Pause immediately stops audio/haptics and centers the pendulum.
- Resume immediately restarts steady clicks.
- Stop immediately returns to ready state.
- Running BPM changes apply on the next click boundary rather than cutting or restarting the current click.

## Playback State And Data Flow

Replace the UI's binary `isPlaying` assumption with a Garage-local session state:

- `ready`
- `countingIn` for Guided Swing only
- `playing`
- `paused`

`Stop` returns to `ready`. `Pause` moves `countingIn` or `playing` to `paused`. `Resume` follows the active service's start rule.

Each page has two BPM concepts while running:

- `savedBPM`: bound to its `@AppStorage` value and updated by the slider.
- `appliedBPM`: the BPM currently driving audio and visuals.

When ready or paused, `appliedBPM` adopts `savedBPM` before the next start. While playing, a change to `savedBPM` becomes pending and is committed at the next service-safe boundary:

- Guided Swing: next full Start boundary after impact/rest.
- Metronome: next click boundary.

The engine must expose boundary-safe timing updates rather than resetting its render base frame immediately during a cycle.

## Audio Design

### Guided Swing Start Cue

- Three short, clean generated ticks.
- Even spacing.
- Final tick leads directly into the Start of the build.
- No spoken numbers, dramatic riser, extra screen, or background click loop.
- Haptic start pulses may mirror the ticks when haptics are enabled.

### Guided Swing Cycle

- One continuous generated tonal build through takeaway and transition.
- Faster release into a clear impact crash.
- Silence during configured rest/reset.
- One selected sound style controls the complete build and impact character.
- Preserve generated DSP and the separate live-loop versus one-cycle preview paths.

### Metronome Cycle

- One steady generated click per beat.
- No first-beat accent.
- No subdivisions or additional cue layers.
- Existing click synthesis may remain internal, but public Metronome sound selection is removed for this pass.

### Immediate Stop Contract

Pause and Stop must silence output immediately from the user's perspective. A very short anti-click fade may remain inside the render engine, but UI state, haptics, and visible motion stop at once.

## Haptics

Haptics remain a small local preference, not a new system.

- Guided Swing:
  - light pulses for count-in
  - restrained cue at Top
  - firm cue at Impact
- Metronome:
  - light pulse on each click
- Pause and Stop cancel future haptic scheduling immediately.
- Reduce Motion does not disable haptics; the Control Room toggle does.

## Control Room

Control Room opens with `fullScreenCover` and uses custom Garage surfaces arranged like compact Apple Settings grouped rows. Do not use default `List` or `Form`.

### Guided Swing Rows

1. Active Swing BPM readback
2. Sound Style
3. Preview Guided Swing
4. Rest Between Swings
5. Haptics
6. Start Cue readback: `Three clean ticks`

Sound Style opens one clean list. Each row includes:

- practical name
- concrete sound description
- explicit selected state
- preview button

The list must exclude novelty profiles and must not expose separate Start, Top, or Impact customization.

### Metronome Rows

1. Active Metronome BPM readback
2. Preview Click
3. Haptics

Do not expose accent, subdivision, build, impact, rest, or click-library controls.

## Sound Library Copy

Rename public Guided Swing styles toward concrete sound descriptions. Final names should be selected from the existing premium generated profiles after listening QA. Recommended direction:

- `Clean Pulse` - Sharp, precise build with a clean strike.
- `Low Punch` - Deeper build with a compact impact.
- `Glass Tick` - Bright, tight build with a precise strike.

Do not publish profiles that sound playful, cartoon-like, sci-fi-heavy, distracting, or novelty-driven.

## File Ownership And Expected Changes

- `LIFE-IN-SYNC/Garage/GarageHomeTabView.swift`
  - Saved Guided Swing BPM readback and Home copy/chip cleanup.
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
  - Two-service state, separate BPM bindings, page order, horizontal timeline, main controls, toast, full-screen Control Room, and sound list presentation.
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
  - Guided Swing count-in, no Guided Swing background clicks, boundary-safe BPM updates, immediate pause/stop behavior, and steady Metronome contract.
- `LIFE-IN-SYNC/Garage/GarageSlowTempoLogic.swift`
  - Only if needed to expose a clean shared Start / Top / Impact progress model.
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
  - Only if compilation or focused listening verification requires contract alignment.

Do not modify `GarageTempoWizard.swift`; it is not the live routed screen.

## Implementation Phases

### Phase 1: State And Source Of Truth

- Add separate saved Metronome BPM.
- Make Home read the saved Guided Swing BPM.
- Put Guided Swing first.
- Add ready/count-in/playing/paused state.
- Add saved versus applied BPM handling and saved-feedback toast.

### Phase 2: Main UI

- Replace Guided Swing J-arc with the horizontal timeline.
- Keep sliders visible while running.
- Add Pause/Resume/Stop controls.
- Remove main-screen sound controls.
- Refine Metronome pendulum and page indicator.

### Phase 3: Control Room

- Convert to full-screen custom grouped settings.
- Add active-page-specific rows.
- Move Guided Swing sound, rest, preview, and haptics into Control Room.
- Remove Guided Swing background-click UI and Metronome sound-library UI.

### Phase 4: Audio And Haptics

- Add Guided Swing three-tick count-in.
- Enforce no background clicks for Guided Swing.
- Enforce steady-click-only Metronome.
- Apply BPM changes at safe service boundaries.
- Add and cancel haptics with session state.

### Phase 5: Verification And Tuning

- Verify persistence, pause/resume/stop, page switching, and next-cycle BPM behavior.
- Listen to all public Guided Swing styles and remove or rename weak profiles.
- Check outdoor-relevant contrast and Reduce Motion behavior.

## Acceptance Criteria

- Garage Home and Guided Swing show the same saved Guided Swing BPM.
- Guided Swing and Metronome retain separate saved BPM values.
- Guided Swing is the first/default page.
- Each page shows only its own BPM.
- No visible Full Swing, Short Game, Putting, club, or ratio controls appear.
- Guided Swing main screen uses a thin Start / Top / Impact timeline with a moving marker and clear impact pulse.
- Guided Swing has no background clicks.
- Guided Swing Start and Resume use three clean ticks before a fresh build cycle.
- Metronome Start and Resume begin steady clicks immediately.
- Metronome has no accents, subdivisions, build, or impact crash.
- Both BPM sliders remain visible and editable while running.
- Running BPM changes apply at the next safe boundary without resetting the active swing/click.
- BPM changes auto-save and show `Tempo saved`.
- Guided Swing pending changes show `Applies next swing`.
- Pause immediately stops audio/haptics and resets the visual.
- Stop immediately returns to ready without a summary or save prompt.
- Control Room opens full-screen and shows only active-service rows.
- Main pages do not expose Sound Style, rest timing, or preview controls.
- No SwiftData schema, routing, shell, or unrelated Garage changes are introduced.

## Verification Plan

### Static

- `git diff --check`
- focused `xcrun swiftc -parse` for touched Garage Swift files
- search for removed live copy and controls:
  - `Background Clicks`
  - main-screen sound buttons
  - hardcoded Home `60`

### Build

- focused Xcode target build with code signing disabled

### Runtime

- Confirm Home and Guided Swing BPM match after relaunch.
- Confirm Guided Swing and Metronome BPMs remain independent after relaunch.
- Confirm page switching stops playback.
- Confirm Guided Swing count-in, build, impact, and rest.
- Confirm Metronome starts immediately and stays steady.
- Confirm Pause, Resume, and Stop are immediate.
- Change BPM during playback and confirm the active cycle is not disrupted.
- Confirm Control Room previews do not begin the live loop.
- Confirm Reduce Motion and haptics toggle behavior.
- Perform real-device listening QA before claiming audio quality.

## Explicit Non-Goals

- No SwiftData migration.
- No new shell or routing architecture.
- No club-based tempo profiles.
- No tempo synchronization between services.
- No session summary or analytics.
- No separate Start, Top, and Impact sound customization.
- No Metronome accent, subdivision, or sound-library expansion.
- No unrelated Garage cleanup.

