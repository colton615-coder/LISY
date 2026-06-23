# Guided Swing Premium Lift Hill No-Exhale Design

**Date:** 2026-06-23

**Status:** Design approved for written spec review

**Scope:** Garage Tempo Builder, Guided Swing audio only

## Goal

Revise the Premium Lift Hill Guided Swing direction so the phrase has no human exhale, breath, vocal cue, or top-of-swing sound.

The approved sequence is:

1. a slow, steady rollercoaster chain-lift climb through the backswing;
2. a sharp stop at the top with only a tiny technical de-click fade;
3. exact digital silence through the downswing;
4. the user-supplied golf-swing WAV at impact.

The phrase must feel like a rollercoaster being pulled up at high altitude, then released into a real golf strike. It must remain serious, athletic, repeatable, and clear on an iPhone speaker while preserving the existing Tempo Builder timing and session contracts.

## Current System Observed

The live route is:

`GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`

`GarageTempoSessionController` owns count-in, rest, pause/resume, cycle boundaries, haptics, and pending BPM application. It passes a `GarageGuidedSwingCycleSchedule` into `ElasticSlingshotAudioEngine` for each Guided Swing cycle.

The live app has not yet been changed to use the external Premium Lift Hill assets. Existing external audition files are listening artifacts only.

The previous exhale direction is now rejected. Do not source, bundle, schedule, or preserve any exhale asset for this phrase.

## Approved Sound Sequence

### Backswing: high-altitude chain lift

A close, muted steel chain-lift texture begins at the start of the backswing and continues to the exact top boundary.

The source identity is the user-selected rollercoaster ratchet WAV:

`/Users/colton/Downloads/171510__esperar__rollercoaster-ratchet.wav`

Observed source format:

- mono;
- 44.1 kHz;
- 16-bit linear PCM WAV;
- approximately 18.715 seconds;
- CC0 source selected by the user for the chain-lift identity.

The chain-lift must:

- read as a rollercoaster being pulled upward at altitude;
- stay slow, steady, mechanical, and weighty;
- build loudness and pressure toward the top;
- avoid a musical note, piano identity, synth rail, or pitch sweep;
- avoid an evenly accented metronome feel;
- avoid theme-park bells, crowd noise, squeals, playful wooden-coaster character, or novelty texture;
- stop decisively at the top boundary with only a tiny de-click fade.

At different BPM values, the source may be looped or assembled from predecoded segments to cover the scheduled backswing. Playback-rate changes must remain subtle enough that the chain mechanism does not become chipmunk-like or unnaturally slow.

### Top: no exhale

There is no top sound.

Specifically forbidden:

- human exhale;
- inhale;
- gasp;
- grunt;
- spoken cue;
- vocal texture;
- breathy transition;
- synthetic replacement for a breath.

The chain may receive a short technical de-click fade at the top boundary only to prevent an audio pop. That fade is not a musical or player-facing event.

### Downswing: complete silence

The complete scheduled downswing is silent.

No air sweep, zipper, pitch fall, click, breath, whisper, pre-impact cue, or impact pre-roll may be audible during this interval.

This silence is intentional. The stored-load chain climb creates the tension; the clean empty gap creates the release; the real WAV impact resolves it.

### Impact: supplied golf-swing WAV

The impact source is:

`/Users/colton/Downloads/816986__luisa_sanchez__golf-swing.wav`

Observed source format:

- mono;
- 44.1 kHz;
- 24-bit linear PCM WAV;
- approximately 0.658 seconds;
- CC0 source selected by the user for the impact identity.

The WAV is the sole impact source. Do not layer drums, sticks, metal hits, crashes, generated transients, or synthetic body beneath it.

The production edit may trim leading or trailing silence, apply a short de-click fade, normalize conservatively, and remove unusable room tail. It must not reshape the file into a different impact identity.

The actual strike transient within the source must align with `impactOffset`. If the source contains pre-strike movement, the edit must either trim it or render it inaudibly before impact so the downswing remains silent.

## Timing Contract

`GarageGuidedSwingCycleSchedule` remains the timing authority.

For every supported BPM:

- the chain lift begins at cycle time `0.0`;
- it fills the complete backswing and stops at `topOffset`;
- the interval from `topOffset` through `impactOffset` is silent except for the inaudible technical de-click fade at the chain stop;
- the complete interval from `downswingOffset` to `impactOffset` is exact digital silence;
- the supplied WAV's strike transient aligns with `impactOffset`;
- its natural tail may continue only inside the existing completion/rest boundary.

Audio must not introduce a second scheduler, fixed timing table, or mode-specific BPM synchronization.

## Product and Architecture Constraints

- Do not redesign the Tempo Builder screen or Guided Swing hero.
- Do not change navigation, persistence keys, BPM storage, or mode routing.
- Do not synchronize Guided Swing BPM with Metronome BPM.
- Do not change spoken count-in, rest, pause/resume, haptics, or pending-BPM boundary behavior.
- Do not alter Metronome sounds or behavior.
- Do not add third-party packages or runtime downloads.
- Do not expose a player-facing sound library for this work.
- Do not use a procedural or synthetic fallback when production assets are absent.
- Do not keep a hidden exhale branch, inactive exhale asset, or fallback exhale path.

## Audio Asset Contract

The production phrase uses two source roles:

- `backswing_premium_lift_hill.wav`
- `impact_golf_swing.wav`

Production assets must be:

- legally usable in a commercial app;
- documented with source, author, URL, license, attribution requirements, edits, and phrase role;
- mono PCM WAV at 44.1 kHz or 48 kHz;
- dry, tightly trimmed, and free of unrelated ambience;
- mastered with conservative headroom and no clipped peaks;
- accepted through physical-iPhone listening before production promotion.

The source manifest is authoritative. The phrase is unavailable unless every required asset is present, decodable, and documented.

## Baseline and Candidate Policy

The previously approved external baseline remains archived:

`/Users/colton/Desktop/LIFE-IN-SYNC Guided Swing Audio QA/Approved Baseline/guided_swing_premium_lift_hill_baseline.wav`

That baseline contains an exhale and is no longer the desired final behavior. It should not be deleted or overwritten because it remains useful for A/B comparison of chain lift, loudness, impact alignment, and mastering.

Every no-exhale experiment must be rendered into a new candidate folder with a new filename. A no-exhale candidate replaces the baseline only after explicit listening approval.

## Asset Loading and Render Integration

Assets are loaded and decoded before playback. Decoded mono floating-point buffers are retained by the audio engine or a dedicated immutable sample library.

No file access, decoding, heap allocation, logging, string building, or lock-taking may be added to the audio render callback.

The loader must distinguish ready, missing file, unreadable file, unsupported format, and invalid-manifest states. DEBUG QA shows the exact unavailable state. Production fails safely instead of restoring rejected synthesis.

The renderer uses the existing one-cycle path and cycle token:

1. Loop or segment the chain-lift buffer with crossfaded boundaries across the exact backswing duration.
2. Apply the rising load envelope and stop the chain at `topOffset`.
3. Apply only a tiny technical de-click fade at the chain stop.
4. Emit exact digital silence from the top release through the scheduled downswing.
5. Pre-roll the impact asset only when necessary to align its internal strike transient with `impactOffset`; any pre-roll before impact must be inaudible.

This preserves count-in, rest, resume, pending BPM, UI, haptics, and audio alignment under `GarageTempoSessionController`.

## Audition Workflow

Before live integration, create one external 60 BPM no-exhale audition using:

- the user-selected `171510__esperar__rollercoaster-ratchet.wav` chain-lift source;
- the user-selected `816986__luisa_sanchez__golf-swing.wav` impact source.

Do not reuse the rejected held-note, downswing, exhale, or cartoon impact layers. The audition must preserve the live phase timing, including the silent top release and silent downswing.

After listening approval:

1. verify and document source licensing;
2. add only the approved production edits;
3. validate file presence, decoding, channel count, sample rate, peak level, and manifest completeness;
4. preview through the production renderer at representative BPM values;
5. compare on built-in iPhone speaker and headphones;
6. promote the assets only after physical-device acceptance.

## Failure Handling

- Missing or invalid assets prevent Guided Swing audio from starting and expose a development-visible failure.
- The engine must not crash, partially play a phrase, or substitute an oscillator.
- Route-change and audio-session interruption behavior remain owned by the existing engine and session controller.
- Route-specific gain treatment may apply only at a cycle boundary.

## Files Likely Involved

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/GarageGuidedSwingAudioProfile.swift`
- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPhrasePreview.swift`
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
- Guided Swing audio assets and source manifest
- focused tests for asset readiness, timing, silence, and fallback policy

`GarageTempoSessionController.swift` and `HorizonVaultDialView.swift` should remain behaviorally unchanged unless implementation inspection proves a narrow integration change is required. Broader session, persistence, route, or UI changes require separate approval.

## Verification and Acceptance

### Static verification

- Focused Swift parsing succeeds for every changed Swift file.
- `git diff --check` succeeds.
- Focused tests cover asset readiness, timing math, exact silence, and impact-transient alignment where available within the verification budget.

### Behavioral verification

- Spoken count-in occurs before the first swing and again on Resume.
- Guided Swing and Metronome retain separate BPM memory.
- Saved BPM changes retain next-full-swing-boundary behavior.
- Rest, pause, resume, stop, haptics, and cycle-token alignment remain intact.
- No Guided Swing piano phrase, held oscillator, downswing sweep, exhale, or generated impact is audible.
- The top release is silent after the chain stop.
- The downswing is digitally silent.
- Missing or invalid assets never trigger a synthetic fallback.

### Listening acceptance

Static checks cannot approve audio quality. Final acceptance requires listening on a physical iPhone speaker at low, medium, and high practical volume, plus a headphone check.

The phrase passes only if:

- the backswing unmistakably reads as a premium steel chain lift under increasing load;
- the chain feels like a high-altitude rollercoaster climb, not a toy ratchet;
- the chain stop is clean and decisive without a breath cue;
- the top release and downswing are silent;
- the supplied WAV lands exactly at impact and remains recognizable as a real golf strike;
- every phase remains legible at 20, 60, and 75 BPM;
- repeated cycles do not become fatiguing.

## Risks

- Chain-lift recordings often contain theme-park ambience, squeals, voices, or long reverberation that cannot be cleanly removed.
- Repeating a short ratchet loop can create a cheap metronomic pattern unless loop seams and accents are controlled.
- Removing the exhale makes the transition more exposed, so the chain stop and silence must be technically clean.
- The supplied WAV may contain pre-strike motion or tail that requires editing for exact impact alignment.
- iPhone speakers exaggerate ratchet transients and remove low mechanical body, so headphone-only mastering is insufficient.
- Licensing mistakes are a release risk; undocumented assets cannot ship.

## Done Conditions

The implementation is complete only when:

1. The external no-exhale Premium Lift Hill audition is approved.
2. A documented, legally usable two-file production kit exists in the repo.
3. Live Guided Swing uses the sample-backed production renderer.
4. The rejected musical, procedural, zippy, exhale, and clown-like sounds are absent from live playback.
5. The top release and downswing are silent and the supplied WAV's strike transient aligns with impact.
6. Timing and session invariants remain intact.
7. No synthetic fallback exists for missing Guided Swing assets.
8. Focused static verification passes.
9. Physical-iPhone listening approves the final source and master.
