# Guided Swing Premium Lift Hill Implementation Plan

**Date:** 2026-06-22

**Design authority:** `docs/superpowers/specs/2026-06-22-guided-swing-premium-lift-hill-design.md`

**Scope:** Replace the live procedural Guided Swing identity with one sample-backed Premium Lift Hill phrase: chain-lift backswing, slight exhale at the top, silent downswing, and the user-supplied golf-swing WAV aligned to impact.

## Goal

Deliver the approved phrase on the live Tempo Builder route without changing navigation, session scheduling, persistence keys, separate Guided Swing and Metronome BPM memory, count-in, rest, haptics, or Metronome audio.

## Current System Observed

- Live route: `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`.
- `GarageTempoSessionController` remains the count-in, rest, pause/resume, cycle, and pending-BPM authority.
- `GarageGuidedSwingCycleSchedule` remains the shared UI, haptic, and audio timing authority.
- `ElasticSlingshotRenderState` currently renders Guided Swing phases sample by sample through procedural identity functions.
- `GuidedSwingInstrumentPhrasePreview.swift` is DEBUG-only, uses four obsolete Muted Rhodes slots, and schedules independent `AVAudioPlayer` instances rather than the production renderer.
- `GarageGuidedSwingProfile`, `TempoSoundIdentityProfile`, and their tests still describe three rejected rail identities.
- `garage.tempoBuilder.guidedSound` must remain the persistence key; all legacy values must migrate to the new single identity.
- The current Guided Swing source manifest contains no production assets.

## Preserved Contracts

- No route, navigation, root-shell, or screen redesign.
- No change to spoken count-in or Resume count-in.
- No change to rest, pause, resume, stop, cycle-token, or next-full-swing BPM behavior.
- No synchronization between Guided Swing BPM and Metronome BPM.
- No change to Metronome playback, assets, or fallback behavior.
- No player-facing instrument or sound-effects browser.
- No runtime downloads or third-party packages.
- No synthetic or procedural fallback for missing Guided Swing assets.
- No file access, decoding, allocation, logging, string building, or lock-taking added to the render callback.

## Phase 1: Source Validation and External Audition

### Task 1.1 — Verify the supplied impact asset

Input:

`/Users/colton/Downloads/816986__luisa_sanchez__golf-swing.wav`

Actions:

1. Locate the original source page using the Freesound-style asset ID and author embedded in the filename.
2. Record the exact license, author, source URL, attribution requirement, and redistribution terms.
3. Stop if commercial app redistribution is unclear; do not copy the file into the repo.
4. Analyze the waveform to locate the actual club/ball strike transient and measure leading motion, useful tail, peak, and clipping.
5. Produce a non-destructive working edit outside the repo with only trim, de-click fades, conservative gain, and necessary tail cleanup.

Acceptance:

- The strike transient location is documented to sample or millisecond precision.
- Licensing is explicit enough for app-bundle redistribution.
- The working edit remains recognizably the supplied recording and has no clipping.

### Task 1.2 — Source the chain lift and exhale

Actions:

1. Find a legally usable, dry mechanical chain-lift recording with muted steel ratchet detail and low motor/load body.
2. Reject sources containing voices, music, crowd noise, bells, wheel squeal, strong room reverb, or playful wooden-coaster character.
3. Find a separate legally usable, dry, restrained human exhale.
4. Prefer CC0 or an equally explicit commercial redistribution license.
5. Record provenance before editing; ambiguous assets remain unavailable.

Acceptance:

- Chain source sounds mechanical and weighted rather than metronomic or toy-like.
- Exhale is brief, neutral, and free of spoken content.
- Both sources have documented app-redistribution rights.

### Task 1.3 — Create one 60 BPM audition outside the repo

Output location:

`/Users/colton/Desktop/LIFE-IN-SYNC Guided Swing Audio QA/Premium Lift Hill Candidate 01/`

Sequence:

1. Chain lift begins at `0.0` and fills the live 60 BPM backswing.
2. Chain intensity rises toward `topOffset` without a musical pitch sweep.
3. Chain stops at `topOffset` with a de-click fade.
4. Slight exhale begins at `topOffset` and ends by `downswingOffset`.
5. The complete downswing from `downswingOffset` to `impactOffset` is digitally silent.
6. The supplied WAV is pre-rolled only as needed so its internal strike transient aligns exactly with `impactOffset`.
7. Preserve headroom and export mono 44.1 kHz PCM WAV.

Acceptance:

- No rejected prototype layer is reused.
- The downswing interval measures as digital silence.
- The strike transient aligns with the live impact boundary.
- The audition folder contains the composite, source notes, and measured timing/peak summary.

### User listening gate

Stop after the external audition. Do not add audio assets or change live Swift code until the user explicitly approves the candidate after listening.

## Phase 2: Prepare the Production Asset Kit

### Task 2.1 — Create production assets

After listening approval, create:

- `backswing_premium_lift_hill.wav`
- `top_slight_exhale.wav`
- `impact_golf_swing.wav`

Store them under a renamed Guided Swing production-audio folder rather than `Metronome_Audio`.

Each file must be mono PCM WAV at 44.1 kHz or 48 kHz, tightly trimmed, de-clicked, unclipped, and mastered with conservative headroom.

### Task 2.2 — Replace obsolete preview provenance

Files:

- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPreview_Audio/README.md`
- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPreview_Audio/GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json`

Actions:

1. Rename the folder and manifest to production-neutral Guided Swing names.
2. Record source author, URL, license, attribution, original filename, edits, role, sample rate, channel count, peak, and strike-transient offset.
3. Mark readiness only when all three assets are present, decodable, and fully documented.
4. Preserve `fallback_policy: none`.
5. Check Xcode resource membership and bundle basenames to prevent duplicate-resource build failures.

## Phase 3: Replace Obsolete Profile and Preview Models

### Task 3.1 — Collapse Guided Swing to one identity

Files:

- `LIFE-IN-SYNC/Garage/GarageGuidedSwingAudioProfile.swift`
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift` only if the existing readback requires a narrow compatibility update

Actions:

1. Introduce one stable production identity, `premiumLiftHill`.
2. Describe the exact roles: chain build, top exhale, silent downswing, real impact, optional natural impact tail.
3. Migrate every historical raw value to `premiumLiftHill` while retaining `garage.tempoBuilder.guidedSound`.
4. Keep Control Room as a readback plus `Preview Guided Swing`; do not add a sound picker.
5. Remove rejected rail identities from player-facing and QA listening orders once migration tests cover them.

Acceptance:

- Existing saved values resolve to Premium Lift Hill.
- The persistence key and separate BPM memory remain unchanged.
- Control Room exposes no novelty library.

### Task 3.2 — Replace the DEBUG four-slot preview contract

Files:

- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPhrasePreview.swift`
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
- `LIFE-IN-SYNCTests/GuidedSwingInstrumentPhrasePreviewTests.swift`

Actions:

1. Replace the four obsolete Rhodes slots with chain, exhale, and impact roles.
2. Expand readiness states to include missing, unreadable, unsupported format, and incomplete manifest.
3. Make QA readiness use the same production asset definitions as the live engine.
4. Remove independent phrase scheduling from the DEBUG preview player.
5. Route full-sequence preview through `ElasticSlingshotAudioEngine.playOneCycle` so QA exercises production timing.
6. Keep generated fallback explicitly disabled.

Acceptance:

- DEBUG QA reports precise readiness failures.
- Full-sequence preview follows the production renderer and live schedule.
- No obsolete Muted Rhodes labels, file names, or timing table remain.

## Phase 4: Add the Render-Safe Sample Library

### Task 4.1 — Decode and validate assets before playback

Primary file:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`

Add a narrowly scoped immutable sample library, extracted to a separate Garage file only if keeping it inside the engine would materially reduce clarity.

Actions:

1. Resolve bundle URLs and decode the three WAVs during engine preparation, never inside `render`.
2. Convert to the engine's mono floating-point sample rate before playback.
3. Store contiguous immutable sample buffers plus explicit frame counts and impact-transient alignment metadata.
4. Surface a development-visible preparation failure when any production asset is invalid.
5. Do not start Guided Swing audio when the production kit is unavailable.
6. Leave Metronome preparation and asset behavior unchanged.

Acceptance:

- Rendering performs only indexed reads, scalar envelope math, and preallocated state updates.
- Missing assets cannot silently invoke procedural synthesis.
- Route changes do not invalidate decoded buffers.

### Task 4.2 — Render the approved phase contract

Primary file:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`

Actions:

1. During backswing, read crossfaded chain segments across the exact scheduled duration and apply a rising gain/density envelope.
2. Stop chain playback exactly at `topOffset` with a de-click boundary.
3. Render the exhale only during the top phase and guarantee zero sample contribution by `downswingOffset`.
4. Return exact zero throughout the complete downswing phase.
5. Align the impact buffer's measured strike-transient frame with `impactOffset` using precomputed pre-roll metadata.
6. Allow only the approved natural impact tail during follow-through; do not synthesize a tail.
7. Apply conservative output limiting without flattening the chain dynamics or clipping the impact.
8. Remove the live Guided Swing call path to rejected procedural phase generators after the sample path is proven.

Acceptance:

- Chain, exhale, silence, and impact boundaries are frame-derived from `GarageGuidedSwingCycleSchedule`.
- No allocation, file I/O, logging, or lock acquisition is introduced per rendered sample.
- Downswing output is exactly zero before the impact pre-roll's inaudible region.
- The actual strike transient—not merely the file start—lands at impact.

## Phase 5: Focused Tests and Verification

### Task 5.1 — Update focused tests

Files:

- `LIFE-IN-SYNCTests/GarageTempoBuilderTests.swift`
- `LIFE-IN-SYNCTests/GuidedSwingInstrumentPhrasePreviewTests.swift`
- one narrowly scoped sample-library test file only if separation improves coverage

Required coverage:

- one approved Guided Swing identity;
- migration from every historical saved raw value;
- three required production assets and no generated fallback;
- manifest/readiness failure states;
- chain ends at `topOffset`;
- exhale ends by `downswingOffset`;
- downswing samples are exactly zero;
- impact-transient alignment at `impactOffset` across representative BPM values;
- one-cycle completion and cycle-token behavior remain intact;
- Metronome profiles and behavior remain unchanged.

### Task 5.2 — Run verification within the repo budget

From the repo root:

1. `xcrun swiftc -parse` for each changed Swift file, each capped at 60 seconds.
2. `git diff --check`.
3. Run only focused tests that can complete within the 60-second cap; do not retry a stalled command.
4. Run at most one full Xcode build only if focused parsing/tests expose an integration question that requires it.
5. Do not run Simulator, Computer Use, screenshots, or visual QA unless explicitly requested.

### Task 5.3 — Listening acceptance

Static verification cannot approve audio quality. Final acceptance requires:

- physical iPhone speaker at low, medium, and high practical volume;
- headphone check;
- listening at 20, 60, and 75 BPM;
- confirmation that the chain is recognizable but not playful;
- confirmation that the exhale is slight rather than theatrical;
- confirmation that the downswing is silent;
- confirmation that the supplied strike lands cleanly and repeated cycles are not fatiguing.

## Risks and Controls

- **Unclear license:** do not copy or ship the source; replace it with an explicitly licensed recording.
- **Cheap loop repetition:** use source variation, crossfaded segment boundaries, and a non-uniform load envelope rather than an evenly accented click loop.
- **Exhale becomes gimmicky:** keep it quiet, short, dry, and confined to the top hold.
- **Impact seems late:** align the measured internal transient, not the WAV start.
- **Impact pre-roll leaks into silence:** trim or zero the pre-transient region and prove the downswing interval numerically.
- **iPhone loses mechanical body:** master from source quality and restrained midrange support, not synthetic bass or clipping.
- **Render-path regression:** predecode everything and keep only buffer indexing/envelope work in the callback.
- **Resource duplication:** verify bundle basenames before adding assets.

## Done Conditions

Implementation is complete only when all of the following are proven:

1. The external Premium Lift Hill audition is approved by listening.
2. All three production assets have explicit, documented redistribution rights.
3. The supplied golf-swing recording remains the sole impact identity.
4. Live Guided Swing uses the sample-backed production path.
5. Chain lift fills the backswing, exhale fits the top, downswing is silent, and the actual strike transient aligns with impact.
6. Rejected procedural, musical, zippy, and cartoon-like audio is absent from live Guided Swing.
7. No synthetic fallback exists.
8. Routing, persistence, separate BPM memory, count-in, rest, pause/resume, haptics, pending BPM, and Metronome behavior remain intact.
9. Focused static verification passes within the stated budget.
10. Physical-iPhone listening approves the final production master.
