# Tempo Builder Independent Tools Production Design

- Status: approved design; ready for implementation planning
- Scope: Garage Tempo Builder only
- Date: 2026-06-08
- Live route: `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`

## Summary

Tempo Builder becomes two independent premium rhythm tools sharing one restrained shell:

- **Metronome** trains a fixed `3:1` golf-rhythm cycle using separately selected Start and Impact cues with a completely silent Top.
- **Guided Swing** retains its elongated build-to-impact sound and traveling timeline, followed by a full rest period and a separate spoken/visual `3... 2... 1...` countdown.

The implementation preserves the existing Garage-local SwiftUI route, generated DSP audio architecture, preview path, Swing Capture flow, and independent mode BPM storage.

## Shared Shell

- Keep Back, centered `Tempo Builder`, and Swing Capture in the top bar.
- Remove the top-right Control Room icon.
- Use a 44pt gold track segmented selector with a dark matte sliding active capsule.
- Keep the selector disabled while playback or count-in is active.
- Present one centered moss-charcoal training card with a restrained sage border.
- Keep the BPM slider visible in the main card and disabled while running.
- Present one full-width smart action:
  - stopped: gold `Start`
  - active or counting down: matte-black `Stop`
- Remove Pause and Resume behavior from the public flow.
- Add a tap-only Control Room handle 12pt above the Start/Stop action.
- Disable the Control Room handle while running or counting down.

## Metronome Tool

- Preserve its independent saved BPM.
- Replace the every-beat click loop with a fixed `3:1` golf-rhythm cycle:
  - Start cue at cycle start
  - silent Top after three beats
  - Impact cue one beat later
  - immediate next cycle
- Keep the pendulum visual and align its Start, Top, and Impact landmarks to the same engine timing.
- Stop immediately silences audio and resets the pendulum.
- Add separate persisted Start and Impact sound selections.

### Metronome Sound Library

- Use the existing ten original generated click profiles; do not add bundled audio assets.
- Group profiles under:
  - `Classic Pings`
  - `Electronic Beats`
  - `Real Golf Sounds`
- Control Room exposes separate `Start Sound` and `Impact Sound` rows.
- Selecting a sound immediately saves it and previews only the selected cue role.

## Guided Swing Tool

- Preserve its independent saved BPM and elongated generated sound architecture.
- Keep the traveling timeline visual rather than replacing it with the pendulum.
- Continuous sequence:
  1. elongated swing build
  2. impact
  3. full selected rest period
  4. separate spoken and visual `3... 2... 1...` countdown
  5. next swing
- During rest and countdown:
  - freeze the traveling marker in the center
  - render it matte grey
  - show countdown directly above the BPM readout
- Stop immediately cancels audio, rest, countdown speech, countdown UI, haptics, and visual progress.

### Guided Swing Sound Library

- Launch with the current six generated Guided Swing profiles; do not add new profiles in this implementation.
- Group three strongest curated choices under `Featured`.
- Group the remaining profiles under `More Sounds`.
- Selecting a profile immediately saves it and previews one full Guided Swing cycle.

## Control Room

- Open only by tapping the dedicated handle above Start/Stop.
- Present as a native draggable bottom sheet with standard downward dismissal.
- Disable opening while playback or count-in is active.
- Rows change by active tool:
  - Metronome: active BPM readback, Start Sound, Impact Sound, cue previews, haptics
  - Guided Swing: active BPM readback, Sound Style, full-cycle preview, rest interval, spoken countdown readback, haptics
- Dismissing Control Room stops any preview playback.

## State And Persistence

- Preserve:
  - `garage.tempoBuilder.metronomeBPM`
  - `garage.tempoBuilder.bpm` for Guided Swing
  - selected Guided Swing profile
  - rest interval
  - haptics setting
- Add separate `AppStorage` keys for Metronome Start and Impact profile raw values.
- Do not add SwiftData models or migrations.
- Lock BPM changes while running.
- Require Stop before switching tools or opening Control Room.
- Mode switching while stopped loads that mode's saved BPM without mutating the other mode.

## Audio Architecture

- Preserve `ElasticSlingshotAudioEngine`, `AVAudioEngine`, and `AVAudioSourceNode`.
- Preserve separate continuous-loop and one-cycle preview paths.
- Metronome Start and Impact cues must use sample-accurate event frames derived from the fixed `3:1` cycle.
- Metronome Top must generate total silence.
- Guided Swing must retain its elongated build-to-impact synthesis.
- No system sounds, downloaded packs, bundled samples, third-party audio libraries, or external Tone Vault dependency.

## Accessibility And Motion

- Expose selector options as separate accessible buttons with selected state.
- Announce active tool, current BPM, Start/Stop state, and countdown values.
- Keep Start/Stop and Control Room handle at least 44pt tall.
- Under Reduce Motion, preserve timing and state changes while removing decorative spring or glow movement.

## Implementation Boundaries

- Primary files:
  - `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
  - `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- Touch additional Garage-local files only if compilation requires it.
- Do not change routing, Dashboard, module boundaries, Swing Capture behavior, persistence architecture, or unrelated Garage screens.

## Acceptance Criteria

- Metronome and Guided Swing retain independent BPM values across mode switches and relaunches.
- Selector, slider, and Control Room handle are disabled while active.
- Start becomes Stop during playback/count-in; no Pause or Resume is visible.
- Stop immediately resets all active state.
- Metronome plays only distinct Start and Impact cues in a fixed `3:1` loop; Top is silent.
- Metronome Start and Impact selections persist independently and preview separately.
- Guided Swing retains the elongated build sound and traveling timeline.
- Guided Swing completes full rest before spoken/visual countdown begins.
- Guided Swing freezes center-grey during rest/countdown.
- Both mode libraries expose only generated local profiles with the approved groupings.
- No temporary QA route or placeholder behavior remains.

## Verification Budget

- Run focused Swift parse checks on changed files.
- Run `git diff --check`.
- Do not run simulator, Computer Use, screenshots, visual QA, whole-app typecheck, or repeated full builds unless explicitly requested.
- If focused parsing fails, fix the error and rerun once.
- Report runtime audio and visual behavior as unverified unless the user explicitly requests runtime QA.
