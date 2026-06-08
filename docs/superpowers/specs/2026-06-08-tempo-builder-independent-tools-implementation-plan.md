# Tempo Builder Independent Tools Implementation Plan

- Design source: `docs/superpowers/specs/2026-06-08-tempo-builder-independent-tools-production-design.md`
- Scope: live Garage Tempo Builder only
- Verification: focused Swift parse checks and `git diff --check` only

## Phase 1: Audio And State Contracts

Update `ElasticSlingshotAudioEngine.swift` before rebuilding the UI:

- Add separate Metronome Start and Impact profile inputs to render configuration, `start`, `update`, and preview APIs.
- Change Metronome continuous timing to a fixed four-beat `3:1` golf cycle:
  - Start cue at frame zero
  - no generated audio at Top
  - Impact cue at the fourth-beat boundary
  - repeat immediately after Impact
- Add a cue-role preview path that plays only the selected Metronome Start or Impact cue.
- Preserve Guided Swing elongated build, impact, generated profiles, and one-cycle preview behavior.
- Keep all audio generated through the existing `AVAudioEngine` / `AVAudioSourceNode` path.

## Phase 2: Session Orchestration

Update `GarageTempoBuilderView` state and playback flow in `HorizonVaultDialView.swift`:

- Persist separate Metronome Start and Impact profile raw values.
- Preserve independent Metronome and Guided Swing BPM values.
- Replace ready/counting/playing/paused with stopped/counting/playing behavior; remove public pause/resume actions.
- Make Start begin the active tool and Stop cancel audio, tasks, speech, countdown, haptics, pending BPM, and visual progress immediately.
- Lock mode switching, BPM sliders, and Control Room access during counting or playback.
- Change Guided Swing orchestration to:
  1. start elongated swing immediately
  2. wait through the complete engine swing and selected rest
  3. run spoken/visual/haptic `3... 2... 1...`
  4. start the next swing
- Keep Metronome running continuously without rest or countdown.

## Phase 3: Premium Shared Shell

Recompose the live screen in `HorizonVaultDialView.swift`:

- Keep Back, centered title, and Swing Capture; remove the top-right Control Room icon.
- Restyle the selector as a gold 44pt track with a dark sliding active capsule and clear active/inactive text states.
- Give both tools the same centered card shell while preserving independent visuals:
  - Metronome pendulum aligned to Start/Top/Impact timing
  - Guided Swing traveling timeline
- Place mode BPM, `TEMPO SPEED (BPM)`, and the disabled-while-running slider inside the shared card.
- During Guided Swing rest/countdown, freeze the marker centered in matte grey and place countdown above BPM.
- Replace current controls with one full-width action:
  - gold Start when stopped
  - matte-black Stop while counting or playing
- Add a tap-only Control Room handle above Start/Stop; disable it while active.

## Phase 4: Control Room And Libraries

Refactor the existing Control Room and sound sheets in `HorizonVaultDialView.swift`:

- Open Control Room only from the new handle.
- Metronome rows:
  - active BPM
  - Start Sound
  - Impact Sound
  - role-specific preview actions
  - haptics
- Group the existing ten generated Metronome profiles into `Classic Pings`, `Electronic Beats`, and `Real Golf Sounds`.
- Guided Swing rows:
  - active BPM
  - Sound Style
  - one-cycle preview
  - rest interval
  - spoken countdown readback
  - haptics
- Group the existing six Guided Swing profiles into three `Featured` choices and three `More Sounds` choices.
- Save selections immediately, preview on tap, and stop preview playback when sheets dismiss.

## Phase 5: Focused Verification

- Run `xcrun swiftc -parse` on:
  - `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
  - `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- Run `git diff --check`.
- Confirm by source inspection:
  - no Pause/Resume public controls remain
  - no Top cue is generated for Metronome
  - Start and Impact profiles persist separately
  - Guided Swing rest completes before countdown
  - no temporary QA route or unrelated file changes were added
- Do not run simulator, Computer Use, screenshots, visual QA, whole-app typecheck, or full build unless explicitly requested.

## Done Conditions

- The live routed Tempo Builder presents two independent tools inside one premium shared shell.
- Metronome uses a sample-accurate fixed `3:1` Start/silent-Top/Impact cycle.
- Guided Swing retains its elongated sound and performs full rest before spoken/visual countdown.
- Both libraries expose the approved generated profiles and groupings.
- Start/Stop is the only public session action.
- Routing, Swing Capture, module boundaries, and persistence architecture remain unchanged.
