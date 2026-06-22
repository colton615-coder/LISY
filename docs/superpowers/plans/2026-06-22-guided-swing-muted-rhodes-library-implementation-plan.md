# Guided Swing Muted Rhodes Library Implementation Plan

> **Superseded:** Do not implement this plan. The current design authority is `docs/superpowers/specs/2026-06-22-guided-swing-premium-lift-hill-design.md`. A replacement implementation plan will be written only after that spec is approved.

**Date:** 2026-06-22

**Design authority:** `docs/superpowers/specs/2026-06-22-guided-swing-muted-rhodes-library-design.md`

**Scope:** Replace live Guided Swing's procedural rail with one sample-backed Muted Rhodes identity and convert the existing DEBUG audition lane into a production-path QA surface.

## Preconditions

Implementation cannot reach completion without four legally usable Muted Rhodes WAV files:

- `backswing_01.wav`
- `backswing_02.wav`
- `backswing_03.wav`
- `impact_confirm.wav`

The recommended sourcing path is a custom recording or commissioned recording with written rights to redistribute the edited WAVs inside the iOS app. A commercial instrument or sample-pack license is insufficient unless it explicitly permits embedding redistributable source samples in an application.

Do not extract and ship sounds from GarageBand, Logic, a virtual instrument, or a purchased sample pack without confirming that exact redistribution right. Do not start the production integration with placeholder synthesized assets.

## Preserved Contracts

- Live route remains `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`.
- `GarageTempoSessionController` remains the count-in, rest, pause/resume, cycle, and BPM-boundary authority.
- `GarageGuidedSwingCycleSchedule` remains the audio/UI/haptic timing authority.
- `garage.tempoBuilder.guidedSound` remains the persistence key.
- Guided Swing and Metronome retain separate BPM memory.
- Metronome audio and fallback behavior remain unchanged.
- Guided Swing uses no generated or procedural audio fallback.
- No player-facing sound browser is added.

## Task 1: Acquire and approve the source kit

### Inputs

Obtain four dry Muted Rhodes recordings from one coherent instrument and recording chain. Record or commission the following musical roles:

1. `backswing_01.wav`: warm starting voicing, restrained attack.
2. `backswing_02.wav`: connected higher or harmonically fuller voicing.
3. `backswing_03.wav`: most energized backswing voicing without brightness or novelty.
4. `impact_confirm.wav`: compact low chord with a fast rounded decay.

### Asset preparation

- Convert to mono PCM WAV at 44.1 kHz.
- Remove leading silence while preserving the natural Rhodes attack.
- Remove room reverb and long release tails.
- Leave conservative headroom; do not normalize every file independently to full scale.
- Match perceived loudness across the three backswing cues.
- Make impact clearly stronger without making it harsh.

### Provenance update

Update:

- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPreview_Audio/GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json`
- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPreview_Audio/README.md`

Record the source, author, original URL or recording session, license or ownership, attribution requirement, exact edits, file format, duration, peak level, and phrase role for every file.

### Gate

Do not continue to production integration until all four files are present, decodable, documented, and approved as one coherent musical phrase in the existing DEBUG audition lane.

## Task 2: Introduce the production sample-kit model and loader

### Files

- Create `LIFE-IN-SYNC/Garage/GarageGuidedSwingSampleLibrary.swift`.
- Create `LIFE-IN-SYNCTests/GarageGuidedSwingSampleLibraryTests.swift`.
- Update the source manifest and README only as required by Task 1.

### Model

Add a small, Guided-Swing-owned model:

- `GarageGuidedSwingSampleRole`
- `GarageGuidedSwingSampleKit`
- `GarageGuidedSwingSampleKitReadiness`
- `GarageGuidedSwingSampleLibrary`

The production library initially contains exactly one complete kit: Muted Rhodes. The API should accept additional kit definitions later, but do not add fake Felt Piano or Rosewood Marimba assets, settings, or production cases in this pass.

The model exposes stable asset names, role order, readiness, and production eligibility. It does not own session timing or user persistence.

### Loader

Load every WAV before starting the audio engine:

1. Resolve the bundled URL under the Guided Swing audio folder.
2. Open with `AVAudioFile` as non-interleaved Float32 PCM.
3. Require one channel and 44.1 kHz for the production kit.
4. Copy channel data into immutable `[Float]` buffers.
5. Return a specific readiness failure for missing, unreadable, unsupported-format, or incomplete kits.

Requiring 44.1 kHz for the first production kit avoids hidden resampling and keeps the initial renderer deterministic. If 48 kHz source material is supplied, convert it offline before committing it.

### Tests

Cover:

- exactly four required roles in stable order;
- correct bundled asset names;
- ready only when all files resolve and decode;
- missing and unreadable files report distinct failures;
- unsupported channel count or sample rate is rejected;
- `allowsGeneratedFallback` remains false;
- production library contains exactly one eligible kit.

Use injected URL and decode functions for failure tests. Use the real committed assets for one integration-level loader test if the test bundle exposes them reliably.

## Task 3: Add sample-accurate Guided Swing event timing

### Files

- Update `LIFE-IN-SYNC/Garage/GarageSlowTempoLogic.swift`.
- Update `LIFE-IN-SYNCTests/GarageTempoBuilderTests.swift` or add a focused timing test file.

### Timeline

Add a pure value type that derives render events from `GarageGuidedSwingCycleSchedule`:

- backswing cue 1 at `0 * topOffset`;
- backswing cue 2 at `1 / 3 * topOffset`;
- backswing cue 3 at `2 / 3 * topOffset`;
- top silence starts at `topOffset`;
- impact cue starts at `impactOffset`.

Convert event times to frames once when a cycle starts. Do not calculate strings, load files, allocate arrays, or perform file operations in the render callback.

Use a short constant-power or smoothstep de-click fade before `topOffset`. Clamp every backswing voice to silence at the top boundary even if its source buffer has remaining frames.

### Tests

At 20, 60, and 75 BPM, verify:

- cue offsets preserve the one-third spacing;
- cue order is strictly increasing;
- backswing voice end never exceeds the top boundary;
- top hold and downswing remain silent;
- impact begins exactly at the schedule's impact frame;
- event calculations are deterministic at the engine's 44.1 kHz sample rate.

## Task 4: Integrate the Muted Rhodes renderer into the live engine

### Files

- Update `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`.
- Update `LIFE-IN-SYNC/Garage/GarageGuidedSwingAudioProfile.swift`.
- Update `LIFE-IN-SYNCTests/GarageGuidedSwingAudioProfileTests.swift`.
- Add focused renderer tests if the current test target can exercise deterministic buffers without starting `AVAudioEngine`.

### Engine initialization

Load `GarageGuidedSwingSampleLibrary` beside the existing Metronome sample library during `ElasticSlingshotAudioEngine` initialization. Pass immutable Rhodes buffers into `ElasticSlingshotRenderState`.

Expose a preparation failure when the production kit is unavailable. Do not report the engine as prepared for Guided Swing and then render silence or an oscillator.

Metronome preparation must remain independent so a Guided Swing asset failure does not break Metronome.

### Render state

Add fixed render-safe state for four sample events. Each active voice needs only:

- source buffer reference;
- start frame;
- current source index derived from the cycle frame;
- gain;
- fade window.

Mix the three backswing buffers when their scheduled ranges overlap. Apply a restrained master gain and the existing output soft limit after summing. Apply route-specific gain only from precomputed configuration and only at a safe cycle boundary.

Render the impact file from its native attack at `impactOffset`; do not stretch it across the impact phase.

### Remove the live procedural path

The Guided Swing `.build`, `.top`, `.downswing`, `.impact`, and `.tail` phases must no longer call `GarageCleanAscendingRailSynthesis` or any other generated trainer function.

Delete procedural Guided Swing functions and profile plans that become unreachable. Retain only synthesis that is still required by Metronome. Do not leave a hidden fallback branch.

### Profile migration

Replace the active Guided Swing choice with `.mutedRhodes` while preserving `garage.tempoBuilder.guidedSound`.

Map all legacy raw values—including `cleanAscendingRail`, `cleanAscendingRailWarm`, `cleanAscendingRailLow`, and retired historical identities—to `.mutedRhodes`. On the next normal persistence write, the stored value may normalize to `mutedRhodes` without losing the user's setting or affecting BPM storage.

Control Room continues to show one read-only Guided Sound value and one preview action. It does not expose the internal candidate library.

### Tests

Verify:

- all legacy raw values migrate to Muted Rhodes;
- Muted Rhodes is the default and only player-facing Guided Swing identity;
- Guided Swing has no generated fallback flag or synthesis gain;
- render output is nonzero during backswing cue windows;
- render output is exactly zero from top through the pre-impact interval;
- impact output starts on the exact expected frame;
- output remains bounded after overlapping voices;
- Metronome profile behavior remains unchanged.

## Task 5: Make DEBUG QA use the production path

### Files

- Update `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPhrasePreview.swift`.
- Update `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`.
- Update `LIFE-IN-SYNCTests/GuidedSwingInstrumentPhrasePreviewTests.swift`.
- Update `docs/superpowers/specs/GUIDED_SWING_INSTRUMENT_PHRASE_PREVIEW.md`.

### Changes

Retire the standalone `AVAudioPlayer` phrase scheduler as the final audition mechanism. Keep useful asset-readiness rows, but route Preview through `ElasticSlingshotAudioEngine.playOneCycle` with the same `GarageGuidedSwingCycleSchedule` used by live Guided Swing.

The QA surface should show:

- kit name;
- four asset readiness states;
- source-manifest readiness;
- current output route;
- preview availability;
- a clear failure reason when unavailable.

Do not add production persistence, a player-facing picker, or runtime downloads.

### Tests

Verify that QA preview availability is derived from production-kit readiness and that missing assets disable preview without invoking an alternate renderer.

## Task 6: Preserve session and UI behavior

### Files to inspect before deciding whether edits are necessary

- `LIFE-IN-SYNC/Garage/GarageTempoSessionController.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- `LIFE-IN-SYNCTests/GarageTempoBuilderTests.swift`

Do not edit these files merely to accommodate a new architecture. The current one-cycle call already supplies the schedule and cycle token required by the sample renderer.

If the engine must report a Guided-Swing-specific preparation error, make the smallest interface change that lets the session remain `.ready` rather than starting a silent cycle. Do not change the count-in order, restart behavior, rest loop, haptic boundaries, or pending-BPM application.

Confirm with focused tests that:

- count-in still occurs before the first swing and on Resume;
- a BPM change applies on the next full swing boundary;
- Guided Swing and Metronome BPM values remain independent;
- rest, stop, pause, preview, cycle tokens, and haptics retain current behavior.

## Task 7: Verification and listening handoff

### Static verification budget

From the repo root:

1. Run `xcrun swiftc -parse` on each changed Swift file, with a 60-second cap per command.
2. Run `git diff --check`.
3. Run only focused affected tests if they can complete within one 60-second attempt.
4. Run at most one full Xcode build, only if focused parsing or tests cannot prove integration correctness.
5. Do not run a simulator, screenshots, Computer Use, or visual QA unless explicitly requested.

Do not retry a stalled command. If a test or build stalls, inspect the available build log once and report the limitation honestly.

### Code completion evidence

- Live route still reaches `GarageTempoBuilderView`.
- The production sample kit loads all four committed assets.
- Source manifest has complete, truthful entries.
- Search confirms the live Guided Swing render path cannot reach procedural synthesis.
- Focused timing and fallback-policy tests pass.
- Parse and whitespace checks pass.

### Physical listening handoff

Code completion does not equal audio acceptance. On a physical iPhone, listen at 20, 60, and 75 BPM using built-in speaker volume around 25%, 50%, and 80%, then check headphones.

Accept only if:

- the three Rhodes cues read as one connected backswing;
- the top silence is unmistakable but intentional;
- impact is compact, weighted, and not harsh;
- repeated cycles are not fatiguing;
- no phase sounds synthetic, toy-like, or like a notification;
- low-volume timing remains legible;
- high-volume playback does not distort.

If listening rejects the source identity, replace or remaster the WAV files first. Do not reopen the procedural oscillator family.

## Implementation Order and Stop Gates

1. Source and document the four Rhodes files.
2. Stop for a quick asset audition before production integration.
3. Implement the sample-kit model and loader.
4. Implement pure event timing and tests.
5. Integrate sample rendering and remove live procedural Guided Swing synthesis.
6. Migrate the single player-facing profile.
7. Convert DEBUG QA to the production render path.
8. Run the allowed static verification.
9. Stop for physical-iPhone listening acceptance.

Do not claim the feature complete before both stop gates pass.
