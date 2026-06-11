# Tempo Builder Metronome One-Page Workspace Implementation Plan

- Design source: `docs/superpowers/specs/2026-06-10-metronome-one-page-workspace-design.md`
- Live route: `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView`
- Production scope: `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- Protected behavior: Guided Swing, audio engine, routing, persistence keys, sound profile IDs
- Verification budget: focused Swift parse, `git diff --check`, and at most one timed full Xcode build

## Phase 1: Separate Metronome And Guided Swing Settings Paths

Update `GarageTempoBuilderView` in `HorizonVaultDialView.swift`:

- Keep `presentedSheet` and `GarageTempoControlRoom` for Guided Swing only.
- Remove the Metronome page's `onControlRoom` callback.
- Pass these bindings and actions into `GarageMetronomePage`:
  - `$metronomeBPM`
  - `$startClickRawValue`
  - `$hapticsEnabled`
  - session state
  - playback progress
  - Start and Stop
  - sound preview action
- Add a narrow Metronome preview helper in `GarageTempoBuilderView` or a page-local preview engine.
- Ensure starting or stopping normal playback stops an active preview.
- Keep Guided Swing's `onControlRoom`, Control Room presentation, sound library, rest interval, and haptics settings unchanged.

## Phase 2: Build The One-Page Metronome Workspace

Replace the current `GarageMetronomePage` body with a scrollable workspace and sticky bottom session action:

- Use `ScrollViewReader` and a named primary-control anchor.
- Put BPM controls first.
- Add compact pendulum below BPM controls.
- Add selected sound and Haptics control row.
- Add Quick Sounds section.
- Add inline All Sounds disclosure and expanded library.
- Use a bottom safe-area inset for `GarageTempoSessionControls`.
- Disable sound selection and All Sounds expansion while Metronome is active.
- Keep BPM controls enabled while active.
- Preserve current concise Ready / Running status behavior.

## Phase 3: Add Precise BPM Controls

Add file-local `GarageMetronomeBPMControl`:

- Large centered monospaced BPM readout.
- Minus and plus native Buttons around the readout.
- Each button changes BPM by exactly one.
- Clamp changes to `GarageSlowTempoLogic.consumerBPMRange`.
- Disable minus and plus at their respective limits.
- Keep the existing Slider directly below.
- Add clear accessibility labels and values.
- Do not change `tempoChanged()`; binding changes must continue using the existing immediate-running-update path.

## Phase 4: Compact The Pendulum

Reuse `GarageTempoPendulum`:

- Keep the same playback-progress calculation.
- Keep Ready / Running state behavior.
- Keep Reduce Motion behavior.
- Render inside an approximately 160-point region instead of the current 320-point region.
- Adjust only local frame/layout values needed to prevent clipping.
- Do not change audio timing or playback progress.

## Phase 5: Add Main-Page Sound And Haptics Controls

Add file-local `GarageMetronomeSelectedSoundControl`:

- Display selected sound title and character.
- Include a dedicated preview Button.
- Include a compact native Haptics Toggle.
- Preview must not change selection.
- Keep touch targets at least 44 points.
- Use restrained gold only for preview and active toggle emphasis.

Add the fixed Quick Sounds list:

- `Crisp Marker`
- `Dry Clave`
- `Hardwood Click`
- `Muted Tap`
- `Glass Ping`
- `Digital Pulse`

Add file-local `GarageMetronomeQuickSoundCard`:

- Card tap selects the profile.
- Small play button previews only.
- Selected state uses a restrained gold border and checkmark.
- Card and preview button expose separate accessibility actions.
- Selection remains backed by the existing profile `rawValue`.

## Phase 6: Add Inline All Sounds

Add file-local `GarageMetronomeInlineSoundLibrary`:

- Keep the existing four sound families:
  - Crisp / Marker
  - Soft Practice
  - Signal / Accent
  - Digital / Synthetic
- Expand and collapse inside the Metronome workspace.
- Reuse compact sound cards rather than the existing full-height sheet rows.
- Preview button previews without selecting.
- Card tap selects, stops preview, collapses the library, and scrolls to the primary-control anchor.
- Disable expansion and selection while Metronome is active.
- Announce expanded/collapsed state for accessibility.

## Phase 7: Remove Dead Metronome Sheet UI

After the inline path is wired and source references are confirmed:

- Remove `GarageMetronomeSoundLibrary`.
- Remove `GarageMetronomeSelectionBar`.
- Remove Metronome-only branches from `GarageTempoControlRoom`.
- Remove `.metronomeStart` from `GarageTempoSoundLibrary`.
- Preserve:
  - `GarageGuidedSoundLibrary`
  - Guided Swing Control Room
  - Guided Swing sound-library sheet
  - shared settings helpers still used by Guided Swing
- Keep `GarageTempoControlRoomHandle` because Guided Swing still uses it.

## Phase 8: Focused Source Inspection

Confirm by source inspection:

- Live Metronome page does not present Control Room.
- Live Metronome page does not present Click Sounds sheet.
- Guided Swing still presents Control Room and its sound sheet.
- Metronome quick list contains exactly the approved six profiles.
- All 18 profiles remain reachable through inline All Sounds.
- Preview and selection use separate Button actions.
- Existing `@AppStorage` keys are unchanged.
- `GarageMetronomeClickProfile` IDs are unchanged.
- No `ElasticSlingshotAudioEngine.swift`, route, or persistence-model edit was introduced.

## Phase 9: Verification

Run:

```bash
xcrun swiftc -parse LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift
git diff --check
```

Then run at most one full timed build:

```bash
xcodebuild \
  -project LIFE-IN-SYNC.xcodeproj \
  -scheme LIFE-IN-SYNC \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Stop the build after 60 seconds if it has not completed. Do not retry a stalled build.

## Runtime QA Checklist

- Metronome daily controls are available on one page.
- BPM minus, plus, and slider work at range boundaries.
- Running Metronome applies BPM changes immediately.
- Quick sound preview does not select.
- Quick sound card selects without navigation.
- All Sounds expands inline.
- Expanded sound preview does not select.
- Expanded sound selection collapses the library and returns to primary controls.
- Selected sound persists after relaunch.
- Haptics toggle controls the existing Metronome haptic behavior.
- Sound selection is disabled while Metronome runs.
- Start/Stop remains stable and reachable.
- Pendulum remains aligned and legible.
- Guided Swing remains unchanged.

## Done Conditions

- One production file owns the implementation change.
- Metronome Control Room and Click Sounds sheet are absent from the live Metronome path.
- Quick six and all 18 sounds are available on the Metronome page.
- Preview/select behavior matches the approved interaction.
- BPM and Haptics are directly accessible.
- Compact pendulum and sticky Start/Stop create a stronger premium hierarchy.
- Routing, audio engine, persistence, and Guided Swing behavior remain unchanged.
