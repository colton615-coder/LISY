# Guided Swing Premium Lift Hill No-Exhale Implementation Plan

**Date:** 2026-06-23

**Design authority:** `docs/superpowers/specs/2026-06-23-guided-swing-premium-lift-hill-no-exhale-design.md`

**Scope:** Replace the live procedural Guided Swing identity with one sample-backed no-exhale Premium Lift Hill phrase: high-altitude chain-lift backswing, sharp chain stop, silent release/downswing, and the user-supplied golf-swing WAV aligned to impact.

**Listening baseline:** The previous Candidate 03 baseline remains archived for comparison, but it contains an exhale and is no longer the desired final behavior. The next audio artifact must be a new no-exhale candidate, not an overwrite of the approved baseline.

## Goal

Deliver the no-exhale Premium Lift Hill phrase on the live Tempo Builder route without changing navigation, session scheduling, persistence keys, separate Guided Swing and Metronome BPM memory, count-in, rest, haptics, or Metronome audio.

The target sequence is:

1. chain lift from swing start to the top;
2. clean chain stop at the top with only a tiny de-click fade;
3. silence until impact;
4. user-supplied golf-swing WAV at impact.

## Current System Observed

- Live route: `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`.
- `GarageTempoSessionController` remains the count-in, rest, pause/resume, cycle, and pending-BPM authority.
- `GarageGuidedSwingCycleSchedule` remains the shared UI, haptic, and audio timing authority.
- `ElasticSlingshotRenderState` currently renders Guided Swing phases sample by sample through procedural identity functions.
- `GuidedSwingInstrumentPhrasePreview.swift` is DEBUG-only, uses obsolete instrument slots, and schedules independent `AVAudioPlayer` instances rather than the production renderer.
- `GarageGuidedSwingProfile`, `TempoSoundIdentityProfile`, and related tests still describe rejected rail identities.
- `garage.tempoBuilder.guidedSound` must remain the persistence key; all legacy values must migrate to the new single identity.
- The current Guided Swing source manifest contains no production two-asset no-exhale kit.

## Preserved Contracts

- No route, navigation, root-shell, or screen redesign.
- No change to spoken count-in or Resume count-in.
- No change to rest, pause, resume, stop, cycle-token, or next-full-swing BPM behavior.
- No synchronization between Guided Swing BPM and Metronome BPM.
- No change to Metronome playback, assets, or fallback behavior.
- No player-facing instrument or sound-effects browser.
- No runtime downloads or third-party packages.
- No exhale, breath, vocal cue, or top-of-swing sound.
- No synthetic or procedural fallback for missing Guided Swing assets.
- No file access, decoding, allocation, logging, string building, or lock-taking added to the render callback.

## Phase 1: No-Exhale External Audition

This phase happens before live Swift integration. It produces a listenable candidate outside the repo so the sound can be approved before app behavior changes.

### Task 1.1 — Verify supplied source assets

Inputs:

- `/Users/colton/Downloads/171510__esperar__rollercoaster-ratchet.wav`
- `/Users/colton/Downloads/816986__luisa_sanchez__golf-swing.wav`

Actions:

1. Confirm both local files still exist and are readable.
2. Record source author, URL, license, attribution requirement, original filename, sample rate, channel count, bit depth, duration, and checksum.
3. Stop if commercial app redistribution is unclear; do not copy uncertain assets into the repo.
4. Analyze the golf-swing waveform to locate the actual strike transient and measure leading motion, useful tail, peak, and clipping.
5. Choose the chain-lift segment that best reads as slow, steady, high-altitude cranking without toy-like accents.

Acceptance:

- Both assets have explicit source provenance and redistribution rights.
- The impact transient location is documented to sample or millisecond precision.
- The selected chain material is documented by source time range.

### Task 1.2 — Create No-Exhale Candidate 01

Output location:

`/Users/colton/Desktop/LIFE-IN-SYNC Guided Swing Audio QA/Premium Lift Hill No Exhale Candidate 01/`

Sequence at 60 BPM:

1. Chain lift begins at `0.000s`.
2. Chain fills the live 60 BPM backswing until `topOffset`.
3. Chain gains loudness and pressure toward the top without turning into a pitch sweep.
4. Chain stops at `topOffset` with only a tiny de-click fade.
5. The interval after the chain stop remains silent until impact.
6. The complete downswing interval is digitally silent.
7. The golf-swing WAV is aligned so its internal strike transient lands at `impactOffset`.
8. The impact remains the sole strike source.
9. Export mono 44.1 kHz PCM WAV with conservative headroom.

Acceptance:

- The candidate contains no exhale, breath, air sweep, zipper, synthetic transition, or impact layer.
- The silent interval measures as exact digital zero before impact.
- The strike transient aligns with the live impact boundary.
- The candidate folder contains the composite, source notes, and measured timing/peak summary.

### User listening gate

Stop after the external audition and present the candidate for listening. Do not add audio assets or change live Swift code until the user explicitly approves the candidate.

## Phase 2: Prepare the Production Asset Kit

This phase happens only after listening approval of the no-exhale candidate.

### Task 2.1 — Create production assets

Create:

- `backswing_premium_lift_hill.wav`
- `impact_golf_swing.wav`

Store them under a production-neutral Guided Swing audio folder rather than a Metronome folder or obsolete instrument-preview folder.

Each file must be mono PCM WAV at 44.1 kHz or 48 kHz, tightly trimmed, de-clicked, unclipped, and mastered with conservative headroom.

Do not create, preserve, or bundle `top_slight_exhale.wav`.

### Task 2.2 — Create source manifest

Actions:

1. Record source author, URL, license, attribution, original filename, edits, role, sample rate, channel count, peak, checksum, selected source range, and strike-transient offset.
2. Mark readiness only when both required assets are present, decodable, and fully documented.
3. Preserve `fallback_policy: none`.
4. Check Xcode resource membership and bundle basenames to prevent duplicate-resource build failures.
5. Include a clear statement that no exhale asset is part of the production phrase.

Acceptance:

- The two-file kit is complete and documented.
- Missing or invalid assets produce a precise readiness failure.
- There are no stale exhale entries in the production manifest.

## Phase 3: Replace Obsolete Profile and Preview Models

### Task 3.1 — Collapse Guided Swing to one identity

Files:

- `LIFE-IN-SYNC/Garage/GarageGuidedSwingAudioProfile.swift`
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift` only if existing readback requires a narrow compatibility update

Actions:

1. Introduce one stable production identity, `premiumLiftHill`.
2. Describe the exact roles: chain build, silent release/downswing, real impact, optional natural impact tail.
3. Migrate every historical raw value to `premiumLiftHill` while retaining `garage.tempoBuilder.guidedSound`.
4. Keep Control Room as a readback plus `Preview Guided Swing`; do not add a sound picker.
5. Remove rejected rail identities from player-facing and QA listening orders once migration tests cover them.

Acceptance:

- Existing saved values resolve to Premium Lift Hill.
- The persistence key and separate BPM memory remain unchanged.
- Control Room exposes no novelty library.
- No exhale language appears in player-facing Guided Swing profile copy.

### Task 3.2 — Replace the DEBUG preview contract

Files:

- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPhrasePreview.swift`
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
- `LIFE-IN-SYNCTests/GuidedSwingInstrumentPhrasePreviewTests.swift`

Actions:

1. Replace obsolete instrument slots with chain and impact roles.
2. Expand readiness states to include missing, unreadable, unsupported format, and incomplete manifest.
3. Make QA readiness use the same production asset definitions as the live engine.
4. Remove independent phrase scheduling from the DEBUG preview player.
5. Route full-sequence preview through `ElasticSlingshotAudioEngine.playOneCycle` so QA exercises production timing.
6. Keep generated fallback explicitly disabled.

Acceptance:

- DEBUG QA reports precise readiness failures.
- Full-sequence preview follows the production renderer and live schedule.
- No obsolete instrument, exhale, or rejected timing table remains.

## Phase 4: Add the Render-Safe Sample Library

### Task 4.1 — Decode and validate assets before playback

Primary file:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`

Add a narrowly scoped immutable sample library, extracted to a separate Garage file only if keeping it inside the engine would materially reduce clarity.

Actions:

1. Resolve bundle URLs and decode the two WAVs during engine preparation, never inside `render`.
2. Convert to the engine's mono floating-point sample rate before playback.
3. Store contiguous immutable sample buffers plus explicit frame counts and impact-transient alignment metadata.
4. Surface a development-visible preparation failure when either production asset is invalid.
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
3. Return exact zero after the chain stop and throughout the complete downswing phase.
4. Align the impact buffer's measured strike-transient frame with `impactOffset` using precomputed pre-roll metadata.
5. Keep any required pre-roll inaudible so silence remains true until impact.
6. Allow only the approved natural impact tail during follow-through; do not synthesize a tail.
7. Apply conservative output limiting without flattening the chain dynamics or clipping the impact.
8. Remove the live Guided Swing call path to rejected procedural phase generators after the sample path is proven.

Acceptance:

- Chain, silence, and impact boundaries are frame-derived from `GarageGuidedSwingCycleSchedule`.
- No allocation, file I/O, logging, or lock acquisition is introduced per rendered sample.
- Output is exactly zero between the chain stop and the audible impact.
- The actual strike transient, not merely the file start, lands at impact.

## Phase 5: Focused Tests and Verification

### Task 5.1 — Update focused tests

Files:

- `LIFE-IN-SYNCTests/GarageTempoBuilderTests.swift`
- `LIFE-IN-SYNCTests/GuidedSwingInstrumentPhrasePreviewTests.swift`
- one narrowly scoped sample-library test file only if separation improves coverage

Required coverage:

- one approved Guided Swing identity;
- migration from every historical saved raw value;
- two required production assets and no generated fallback;
- manifest/readiness failure states;
- no exhale source role;
- chain ends at `topOffset`;
- output is zero after the chain stop and before impact;
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
- confirmation that there is no exhale or breath cue;
- confirmation that silence exists after the chain stop and through the downswing;
- confirmation that the supplied strike lands cleanly and repeated cycles are not fatiguing.

## Risks and Controls

- **Cheap loop repetition:** use source variation, crossfaded segment boundaries, and a non-uniform load envelope rather than an evenly accented click loop.
- **Toy-like ratchet:** choose a slower, heavier source range and avoid bright gain boosts that make the chain feel small.
- **Transition feels empty:** keep the silence intentional and clean; do not fill it with breath, whoosh, or zipper audio.
- **Impact seems late:** align the measured internal transient, not the WAV start.
- **Impact pre-roll leaks into silence:** trim or zero the pre-transient region and prove the silent interval numerically.
- **iPhone loses mechanical body:** master from source quality and restrained midrange support, not synthetic bass or clipping.
- **Render-path regression:** predecode everything and keep only buffer indexing/envelope work in the callback.
- **Resource duplication:** verify bundle basenames before adding assets.

## Done Conditions

Implementation is complete only when all of the following are proven:

1. The external no-exhale Premium Lift Hill audition is approved by listening.
2. Both production assets have explicit, documented redistribution rights.
3. The supplied golf-swing recording remains the sole impact identity.
4. Live Guided Swing uses the sample-backed production path.
5. Chain lift fills the backswing, the top release and downswing are silent, and the actual strike transient aligns with impact.
6. Rejected procedural, musical, zippy, exhale, and cartoon-like audio is absent from live Guided Swing.
7. No synthetic fallback exists.
8. Routing, persistence, separate BPM memory, count-in, rest, pause/resume, haptics, pending BPM, and Metronome behavior remain intact.
9. Focused static verification passes within the stated budget.
10. Physical-iPhone listening approves the final production master.
