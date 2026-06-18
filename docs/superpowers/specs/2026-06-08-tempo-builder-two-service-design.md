# Tempo Builder Two-Service Design

- Status: active Tempo Builder product contract; audio synchronization work remains proposed and unverified
- Scope: Garage module only
- Date: 2026-06-08
- Owner surface: live Garage Tempo Builder
- Product input: screen-recording audit and completed Grill Me questionnaire

## Objective

Tempo Builder becomes a focused two-service training tool:

1. `Guided Swing` is the premium swing-rhythm trainer.
2. `Metronome` is the separate steady-click trainer.

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

This contract supersedes one-personal-tempo plans, fixed `3:1` Metronome cycle plans, physical-metronome centerpiece plans, generated-only Guided Swing plans, and exaggerated multi-identity sound targets. Guided Swing and Metronome intentionally retain separate saved BPM values and separate timing behavior.

The approved Guided Swing audio and arc behavior below is an implementation target. This document does not claim that final audio assets, arc synchronization, device listening, or runtime behavior have already been verified.

## Current Live Implementation

The active implementation already has useful foundations:

- `HorizonVaultDialView.swift` owns the live two-page Tempo Builder UI.
- `ElasticSlingshotAudioEngine.swift` owns generated real-time audio, continuous playback, and one-cycle preview.
- `GarageSlowTempoLogic.swift` supplies Guided Swing visual timing.
- `GarageHomeTabView.swift` owns the Garage Home Tempo Builder preview.

Implementation details must be re-checked against the live route before coding. Historical observations in older Tempo Builder specs are not current requirements.

## Locked Product Decisions

### Shared

- Guided Swing and Metronome remain swipeable modes; page ordering is not an audio or architecture contract.
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

- Guided Swing uses a restrained swing arc with Address, Backswing, Top, Downswing, and Impact landmarks.
- The arc owns phase timing. Audio and haptics obey the arc's phase boundaries.
- Visual emphasis is restrained; avoid cheap glow, neon HUD treatment, and decorative motion unrelated to timing.
- Guided Swing follows the audio UX target `smooth load -> clean transition -> crisp strike`.
- Guided Swing has no background clicks.
- Start and Resume use three clean audio ticks before the first build begins.
- The three-tick cue is audio-first because the golfer may be looking at the ball. It does not add a setup screen or spoken coaching.

### Metronome

- Metronome starts and resumes immediately.
- Metronome plays one steady click per beat.
- It has no count-in, accents, subdivisions, build sound, or impact crash.
- Click selection may remain available through Metronome-specific Control Room rows, but it changes timbre only and never cadence.
- Its main visual is a minimal beat indicator, not a required physical-metronome centerpiece.

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
5. restrained swing arc with Address / Backswing / Top / Downswing / Impact landmarks
6. dominant Start button
7. Control Room access in the top bar

Do not show Sound Style, rest timing, Preview Guided Swing, background clicks, or profiles on the main screen.

### Guided Swing Running State

- Keep the BPM readout and slider visible.
- Show Pause and Stop as separate actions.
- Arc marker follows the currently applied playback BPM, not an uncommitted slider value.
- Slider changes auto-save immediately but show `Applies next swing` until the next cycle boundary.
- At the next full-cycle boundary, arc timing and audio scheduling adopt the new BPM together.
- Pause immediately silences audio, cancels pending haptics, and resets the marker to Start.
- Resume begins a fresh three-tick cue, then starts a new full swing cycle.
- Stop immediately silences audio and returns to ready state.

### Guided Swing Arc

- The arc presents Address, Backswing, Top, Downswing, and Impact as one connected motion.
- Backswing occupies the longer loading portion; Downswing is shorter and accelerates into Impact.
- Arc phase boundaries are the timing source of truth. Audio scheduling consumes those boundaries rather than maintaining a separate audio-led approximation.
- During rest, the marker returns to Address and waits there.
- Impact may use a short restrained gold pulse, but the screen must not become a neon cockpit.
- Reduce Motion keeps phase and landmark state changes while removing nonessential travel and glow.

### Metronome Ready And Running States

- Title: `Metronome`
- Support: `Steady click training.`
- Show its own saved BPM and horizontal slider.
- Use a minimal beat indicator that communicates steady cadence without introducing a physical-instrument centerpiece.
- Start begins steady clicks immediately.
- Pause immediately stops audio/haptics and resets the beat indicator.
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

- Address: soft start marker.
- Backswing: noticeable but restrained synthesized rising/load texture.
- Top: polished or imported local clean transition cue.
- Downswing: synthesized quick acceleration/release texture.
- Impact: polished or imported local crisp premium strike.
- Silence during configured rest/reset.
- Synthesized audio owns continuous motion texture because it must follow arc timing precisely.
- Polished or imported local assets may own landmark cues such as Top and Impact.
- Any imported local asset must be bundled, licensed, and available offline.
- Preserve local-first playback and separate live-loop versus one-cycle preview paths where they remain part of the live implementation.
- Do not revive eight sound skins, six exaggerated identities, maximum-impact/listening-fatigue targets, or generated-only restrictions as active requirements.

### Metronome Cycle

- One steady generated click per beat.
- No first-beat accent.
- No subdivisions or additional cue layers.
- Metronome is not a fixed `3:1` Start / Top / Impact golf cycle.
- Click selection may remain available through Metronome-specific rows in the shared Control Room.

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
2. Click Sound
3. Preview behavior where supported by the current sound-library interaction
4. Haptics

Do not expose separate Start and Impact identities, subdivisions, build, impact, or rest controls. A click library changes timbre only; it must not change cadence.

## Sound Direction

Guided Swing is one coherent premium motion-and-landmark grammar, not an active target for eight skins or six exaggerated identities. Any retained choices must support the same arc-led timing and `smooth load -> clean transition -> crisp strike` hierarchy.

Metronome click names should remain concrete and name-true. Neither mode should publish playful, cartoon-like, sci-fi-heavy, distracting, or novelty sounds.

## File Ownership And Expected Changes

- `LIFE-IN-SYNC/Garage/GarageHomeTabView.swift`
  - Saved Guided Swing BPM readback and Home copy/chip cleanup.
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
  - Two-service state, separate BPM bindings, swing arc, main controls, toast, shared Control Room, and sound list presentation.
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
  - Guided Swing count-in, no Guided Swing background clicks, boundary-safe BPM updates, immediate pause/stop behavior, and steady Metronome contract.
- `LIFE-IN-SYNC/Garage/GarageSlowTempoLogic.swift`
  - Only if needed to expose clean Address / Backswing / Top / Downswing / Impact arc timing.
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
  - Only if compilation or focused listening verification requires contract alignment.

Do not modify `GarageTempoWizard.swift`; it is not the live routed screen.

## Implementation Phases

### Phase 1: State And Source Of Truth

- Add separate saved Metronome BPM.
- Make Home read the saved Guided Swing BPM.
- Add ready/count-in/playing/paused state.
- Add saved versus applied BPM handling and saved-feedback toast.

### Phase 2: Main UI

- Align the Guided Swing arc with the approved five-landmark timing grammar.
- Keep sliders visible while running.
- Add Pause/Resume/Stop controls.
- Remove main-screen sound controls.
- Refine the Metronome beat indicator and page indicator without introducing a physical-instrument centerpiece.

### Phase 3: Control Room

- Convert to full-screen custom grouped settings.
- Add active-page-specific rows.
- Move Guided Swing sound, rest, preview, and haptics into Control Room.
- Remove Guided Swing background-click UI and keep Metronome click selection mode-specific.

### Phase 4: Audio And Haptics

- Add Guided Swing three-tick count-in.
- Enforce no background clicks for Guided Swing.
- Enforce steady-click-only Metronome.
- Apply BPM changes at safe service boundaries.
- Add and cancel haptics with session state.

### Phase 5: Verification And Tuning

- Verify persistence, pause/resume/stop, page switching, and next-cycle BPM behavior.
- Verify the Guided Swing motion texture and landmark cues against the approved arc-led grammar.
- Check outdoor-relevant contrast and Reduce Motion behavior.

## Acceptance Criteria

- Garage Home and Guided Swing show the same saved Guided Swing BPM.
- Guided Swing and Metronome retain separate saved BPM values.
- Each page shows only its own BPM.
- No visible Full Swing, Short Game, Putting, club, or ratio controls appear.
- Guided Swing uses an arc-led Address / Backswing / Top / Downswing / Impact model with restrained visual emphasis.
- Guided Swing has no background clicks.
- Guided Swing Start and Resume use three clean ticks before a fresh build cycle.
- Metronome Start and Resume begin steady clicks immediately.
- Metronome has no accents, subdivisions, build, or impact crash.
- Metronome is never described or implemented as a fixed golf-swing cycle.
- Both BPM sliders remain visible and editable while running.
- Running BPM changes apply at the next safe boundary without resetting the active swing/click.
- BPM changes auto-save and show `Tempo saved`.
- Guided Swing pending changes show `Applies next swing`.
- Pause immediately stops audio/haptics and resets the visual.
- Stop immediately returns to ready without a summary or save prompt.
- Shared Control Room shows only active-service rows.
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
- No Metronome accent, subdivision, or fixed golf-cycle behavior.
- No speculative calibration, spoken detection, backend, account, or cloud work.
- No third-party packages without explicit approval.
- No unrelated Garage cleanup.
