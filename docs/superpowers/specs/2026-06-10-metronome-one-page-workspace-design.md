# Tempo Builder Metronome One-Page Workspace Design

**Date:** 2026-06-10  
**Status:** Approved design, pending implementation-plan approval  
**Scope:** Metronome page UI/UX only

## Goal

Turn the routed Tempo Builder Metronome page into a stronger premium practice workspace where tempo, click selection, haptics, rhythm feedback, and Start/Stop are available on one page.

The redesign must reduce navigation and visual weakness without changing the audio engine, saved profile identities, separate mode BPM memory, Guided Swing behavior, or Garage routing.

## Live Route And Ownership

- Garage route: `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView`
- Owning implementation file: `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- Audio ownership remains in `ElasticSlingshotAudioEngine.swift`
- Existing metronome persistence remains:
  - `garage.tempoBuilder.metronomeBPM`
  - `garage.tempoBuilder.metronomeStartSound`
  - `garage.tempoBuilder.haptics`

No route, persistence key, or audio-engine change is required.

## Product Diagnosis

### Keep

- Metronome / Guided Swing two-mode structure
- Separate BPM memory per mode
- Existing 18 click sounds and profile IDs
- Existing sound preview behavior
- Current Start/Stop behavior
- Compact pendulum as rhythm feedback
- Guided Swing Control Room and sound library
- Camera action and Garage navigation

### Fix

- Move BPM controls higher and make them the primary hierarchy.
- Make precise one-beat tempo adjustments available without dragging.
- Put click selection and haptics directly on the Metronome page.
- Reduce the pendulum's footprint while preserving useful motion.
- Make sound discovery fast through six representative quick choices.
- Keep the full library available without opening a sheet.
- Keep the Start/Stop action stable and immediately reachable.

### Kill

- Metronome Control Room entry and Metronome Control Room content
- Separate Metronome Click Sounds sheet
- Decorative drawer handle on the Metronome page
- Oversized empty pendulum region
- Redundant Metronome Active BPM and Preview Click settings rows

## Recommended Layout

The Metronome page becomes a vertically scrollable single workspace with a sticky bottom action.

### Fixed Shell

1. Existing top bar
2. Existing Metronome / Guided Swing selector, visually tightened but behavior unchanged
3. Bottom safe-area Start/Stop action

### Scrollable Metronome Workspace

1. **BPM Control**
   - Large centered BPM readout
   - Minus button on the left
   - Plus button on the right
   - Existing BPM slider directly below
   - Minus and plus change BPM by exactly one
   - Buttons respect `GarageSlowTempoLogic.consumerBPMRange`
   - Slider and buttons update a running Metronome immediately through the existing `tempoChanged()` path

2. **Compact Pendulum**
   - Preserve current pendulum motion and playback-progress source
   - Reduce height from the current 320-point region to approximately 150-180 points
   - Keep Ready / Running state legible
   - Remove unnecessary empty vertical space
   - Respect Reduce Motion exactly as the current pendulum does

3. **Selected Sound And Haptics Row**
   - Show selected click title and short character line
   - Include a small play button that previews the selected click without changing selection
   - Include a compact Haptics toggle in the same control region
   - Keep all controls at least 44 points tappable

4. **Quick Sounds**
   - Show six representative options directly on the page:
     - Crisp Marker
     - Dry Clave
     - Hardwood Click
     - Muted Tap
     - Glass Ping
     - Digital Pulse
   - Use compact horizontal or adaptive cards, not full-height list rows
   - Each card contains:
     - Sound title
     - Selection state
     - Small dedicated play button
   - Tapping the play button previews only.
   - Tapping the card selects the sound.
   - Selecting a quick sound keeps the user on the main workspace.

5. **All Sounds Inline Expansion**
   - A single `All Sounds` disclosure expands below Quick Sounds on the same page.
   - The expansion shows the existing four sound families:
     - Crisp / Marker
     - Soft Practice
     - Signal / Accent
     - Digital / Synthetic
   - Each expanded sound card retains separate preview and select actions.
   - Tapping a sound card selects it, stops preview, collapses All Sounds, and scrolls the workspace back toward the main Metronome controls.
   - No sheet, nested sheet, or separate sound-browser screen is used.

6. **Status**
   - Keep concise Ready / Running messaging.
   - Status should support the controls, not occupy a separate dominant region.

## Interaction Rules

### Sound Preview

- Preview play buttons never change the saved selection.
- Preview uses the existing sample-backed `ElasticSlingshotAudioEngine.playOneCycle(...)` path.
- Starting Metronome playback stops any active preview before normal playback begins.

### Sound Selection

- Tapping a sound card writes its existing `rawValue` into `startClickRawValue`.
- Existing saved values continue resolving through `GarageMetronomeClickProfile.migrated(from:)`.
- Selected cards use restrained gold emphasis and a checkmark.
- No new persistence schema is introduced.

### BPM Controls

- Minus and plus buttons adjust by one BPM.
- Controls disable at the range boundaries.
- BPM remains editable while Metronome is running, matching current behavior.
- Guided Swing tempo behavior remains unchanged.

### Haptics

- Haptics remains backed by `garage.tempoBuilder.haptics`.
- The Metronome page toggle directly updates the existing binding.
- No haptic timing or engine behavior changes.

### Active Session Behavior

- Mode switching remains disabled while a session is active.
- Metronome sound selection and All Sounds expansion should be disabled while Metronome is active to avoid accidental context changes.
- BPM adjustment remains enabled while Metronome is active.
- Start becomes Stop through the existing `GarageTempoSessionControls` behavior.

## Component Changes

### `GarageTempoBuilderView`

- Pass `startClickRawValue`, `hapticsEnabled`, and a Metronome preview action into `GarageMetronomePage`.
- Present `GarageTempoControlRoom` only for Guided Swing.
- Keep `presentedSheet` for Guided Swing settings only.

### `GarageMetronomePage`

- Replace the current non-scrollable layout with the one-page workspace.
- Own local `showsAllSounds` state.
- Own a scroll target or `ScrollViewReader` behavior for returning to primary controls after expanded selection.
- Receive bindings for:
  - BPM
  - selected Metronome click raw value
  - Haptics
- Receive a preview callback or use a page-local preview engine, following the existing narrow preview pattern.

### New Local Metronome Components

Add only file-local helpers where they improve readability:

- `GarageMetronomeBPMControl`
- `GarageMetronomeSelectedSoundControl`
- `GarageMetronomeQuickSoundCard`
- `GarageMetronomeInlineSoundLibrary`

Do not create a new design system or move components outside the owning file.

### Existing Components

- Reuse `GarageTempoPendulum`, reduced to a compact frame.
- Reuse `GarageTempoSessionControls`.
- Keep `GarageMetronomeSoundLibrary` only if another live path still uses it; otherwise remove it after confirming no references remain.
- Keep Guided Swing sound sheets and Control Room unchanged.

## Visual Direction

- Premium utility, not decorative cockpit UI
- Dark emerald / black base
- Restrained gold only for selection, preview, and primary action
- Fewer large surfaces
- Compact cards with strong text hierarchy
- No nested sheets
- No oversized labels or ornamental drawer handles
- Use native SwiftUI Buttons and Toggle semantics
- Touch targets at least 44 points

## Accessibility

- Minus and plus buttons announce their tempo adjustment.
- BPM readout announces the current beats per minute.
- Sound cards announce selected state.
- Preview buttons clearly announce `Preview <sound name>` and remain separate from card selection.
- Haptics toggle retains native toggle semantics.
- Expanded All Sounds state is announced.
- Reduce Motion continues disabling or limiting pendulum animation.

## Error And Fallback Behavior

- Missing WAV behavior remains owned by `GarageMetronomeSampleLibrary`.
- Missing or unreadable samples continue falling back to synthesis.
- UI does not expose debug errors or change selection because of a missing asset.
- DEBUG loaded/missing sample logs remain unchanged.

## Verification

### Static

- `xcrun swiftc -parse LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- `git diff --check`
- Confirm no Metronome path presents `GarageTempoControlRoom` or `GarageMetronomeSoundLibrary`.
- Confirm Guided Swing still presents Control Room and its sound picker.
- Confirm no persistence keys or audio profile IDs changed.

### Build

- Run at most one full Xcode build with the repository's 60-second limit.
- Report build success only if compilation completes.

### Runtime Checklist

- BPM minus, plus, and slider update correctly.
- Running Metronome applies BPM changes immediately.
- Quick sound play button previews without selecting.
- Quick sound card selects without navigation.
- All Sounds expands inline.
- Expanded card selection collapses All Sounds and returns focus to the main controls.
- Selected sound persists after relaunch.
- Haptics toggle updates existing behavior.
- Start/Stop remains reachable and stable.
- Guided Swing UI, Control Room, audio, count-in, BPM memory, and rest behavior remain unchanged.

## Done Conditions

- Metronome daily controls exist on one page.
- No Metronome Control Room or Click Sounds sheet remains in the live path.
- Quick six are immediately available.
- All 18 sounds remain available inline.
- Preview and select are separate actions.
- BPM supports slider and one-step minus/plus adjustment.
- Pendulum is compact but still useful.
- Haptics is visible on the main Metronome workspace.
- Existing routing, persistence, audio, and Guided Swing behavior are preserved.
