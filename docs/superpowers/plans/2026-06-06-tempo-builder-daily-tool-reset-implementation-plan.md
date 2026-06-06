# Tempo Builder Daily Tool Reset Implementation Plan

## Scope

Implement the approved daily Tempo Builder reset:

- Metronome default page
- Guided Swing swipe page
- ten original synthesized metronome clicks
- three curated guided sounds
- optional click layering
- minimal sound libraries and settings
- stripped Garage Home preview

Calibration remains a later technical prototype and product phase.

## Tasks

1. Refine `ElasticSlingshotAudioEngine.swift`
   - Add separate metronome-click and guided-sound concepts.
   - Make Metronome one repeating beat at the selected BPM.
   - Remove automatic guided phase clicks.
   - Add optional selected-click layering to Guided Swing.
   - Keep generated real-time audio, preview, loop, and stop-fade behavior.

2. Replace `HorizonVaultDialView.swift`
   - Open directly to Metronome.
   - Add full-page swipe to Guided Swing.
   - Add weighted pendulum and restrained traveling-light arc.
   - Add dedicated click library, guided library, and minimal settings sheets.
   - Persist lightweight preferences with `AppStorage`.
   - Keep camera entry available as existing Swing Capture until Calibration is implemented.

3. Remove `EngineRoomSettingsView.swift`
   - Delete the obsolete live settings identity.

4. Update `GarageHomeTabView.swift`
   - Remove ratio, club chips, and technical timing presentation.
   - Present one simple rhythm service.

5. Verify
   - Run whitespace checks.
   - Parse changed Swift files.
   - Build the app.
   - Inspect the live Tempo Builder route in Simulator when available.

## Guardrails

- Garage only.
- Preserve the live route.
- No SwiftData schema changes.
- No external audio assets or dependencies.
- No Calibration claims in this implementation phase.
- Do not use `GarageTempoWizard.swift` as the live implementation base.
