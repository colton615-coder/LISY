# Guided Swing Premium Lift Hill Design

**Date:** 2026-06-22

**Status:** Premium Lift Hill approved; written spec awaiting review

**Scope:** Garage Tempo Builder, Guided Swing audio only

## Goal

Replace the rejected musical, procedural, zippy, and cartoon-like Guided Swing phrases with one precise sequence:

1. a restrained mechanical chain-lift build through the backswing;
2. a slight exhale at the top;
3. silence through the downswing;
4. the user-supplied golf-swing WAV at impact.

The phrase must feel like stored mechanical load releasing into a real golf strike. It must remain serious, athletic, repeatable, and clear on an iPhone speaker while preserving the existing Tempo Builder timing and session contracts.

## Current System Observed

The live route is:

`GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`

`GarageTempoSessionController` owns count-in, rest, pause/resume, cycle boundaries, haptics, and pending BPM application. It passes a `GarageGuidedSwingCycleSchedule` into `ElasticSlingshotAudioEngine` for each Guided Swing cycle.

The live Guided Swing remains procedural. External listening prototypes have not changed the app.

The following directions are rejected:

- piano, Rhodes, or other obvious instrument phrases;
- sustained oscillator rails;
- pitched or high-passed downswing sweeps;
- zipper, laser, whip, and cabasa effects;
- stacked drum, stick, wood, or metallic novelty impacts;
- cinematic crashes and clown-like resonance.

## Approved Sound Sequence

### Backswing: Premium Lift Hill

A close, muted steel chain-lift texture begins at the start of the backswing and continues to the exact top boundary.

The sound contains two integrated components:

- a low mechanical motor/load bed that communicates stored pressure;
- restrained steel ratchet catches that make the rollercoaster chain-lift identity recognizable.

The chain-lift must:

- become louder and slightly denser toward the top;
- preserve mechanical weight without becoming bright or jangly;
- avoid a musical pitch sweep;
- avoid evenly accented clicks that read as a metronome;
- avoid theme-park ambience, crowd noise, bells, squeals, or playful wooden-coaster character;
- stop decisively at the top with a short de-click fade.

At different BPM values, the source may be looped or assembled from predecoded segments to cover the scheduled backswing. Playback-rate changes must remain subtle enough that the chain mechanism does not become chipmunk-like or unnaturally slow.

### Top: slight exhale

When the chain stops at `topOffset`, one restrained human exhale marks the release of tension.

The exhale must:

- begin at the top boundary;
- remain brief enough to fit inside the existing top-hold interval;
- sound natural, dry, and quiet relative to the chain build;
- avoid spoken syllables, breathy ASMR emphasis, gasps, grunts, or dramatic vocal performance;
- fade completely before the downswing begins.

The exhale is a boundary cue, not a continuous downswing layer.

### Downswing: silence

The complete scheduled downswing is silent. No air sweep, zipper, pitch fall, click, or pre-impact cue is permitted.

This silence is intentional. It creates contrast between stored load at the top and the real strike at impact.

### Impact: supplied golf-swing WAV

The impact source is:

`/Users/colton/Downloads/816986__luisa_sanchez__golf-swing.wav`

Observed source format:

- mono;
- 44.1 kHz;
- 24-bit linear PCM WAV;
- approximately 0.658 seconds.

The WAV is the sole impact source. Do not layer drums, sticks, metal hits, generated transients, or synthetic body beneath it.

The production edit may trim leading or trailing silence, apply a short de-click fade, normalize conservatively, and remove unusable room tail. It must not reshape the file into a different impact identity. The actual strike transient within the source must align with `impactOffset`; blindly starting the file at `impactOffset` is incorrect if the recording contains audible pre-strike movement.

The source file's license and attribution requirements must be verified and recorded before it is copied into the app bundle or treated as production-ready.

## Timing Contract

`GarageGuidedSwingCycleSchedule` remains the timing authority.

For every supported BPM:

- Premium Lift Hill begins at cycle time `0.0`;
- it fills the complete backswing and stops at `topOffset`;
- the exhale begins at `topOffset` and ends no later than `downswingOffset`;
- the complete interval from `downswingOffset` to `impactOffset` is silent;
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

## Audio Asset Contract

The production phrase uses three source roles:

- `backswing_premium_lift_hill.wav`
- `top_slight_exhale.wav`
- `impact_golf_swing.wav`

Production assets must be:

- legally usable in a commercial app;
- documented with source, author, URL, license, attribution requirements, edits, and phrase role;
- mono PCM WAV at 44.1 kHz or 48 kHz;
- dry, tightly trimmed, and free of unrelated ambience;
- mastered with conservative headroom and no clipped peaks;
- accepted through physical-iPhone listening before production promotion.

The source manifest is authoritative. The phrase is unavailable unless every required asset is present, decodable, and documented.

## Asset Loading and Render Integration

Assets are loaded and decoded before playback. Decoded mono floating-point buffers are retained by the audio engine or a dedicated immutable sample library.

No file access, decoding, heap allocation, logging, string building, or lock-taking may be added to the audio render callback.

The loader must distinguish ready, missing file, unreadable file, unsupported format, and invalid-manifest states. DEBUG QA shows the exact unavailable state. Production fails safely instead of restoring rejected synthesis.

The renderer uses the existing one-cycle path and cycle token:

1. Loop or segment the chain-lift buffer with crossfaded boundaries across the exact backswing duration.
2. Apply the rising load envelope and stop the chain at `topOffset`.
3. Trigger the exhale at `topOffset`, guaranteeing silence by `downswingOffset`.
4. Emit exact digital silence through the scheduled downswing.
5. Pre-roll the impact asset only when necessary to align its internal strike transient with `impactOffset`; any pre-roll before impact must be inaudible.

This preserves count-in, rest, resume, pending BPM, UI, haptics, and audio alignment under `GarageTempoSessionController`.

## Audition Workflow

Before live integration, create one external 60 BPM audition using:

- a newly sourced Premium Lift Hill chain recording;
- a newly sourced slight exhale;
- the user-supplied golf-swing WAV.

Do not reuse the rejected held-note, downswing, or impact layers. The audition must preserve the live phase timing, including the silent downswing.

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
- Focused tests cover asset readiness, timing math, exact downswing silence, and impact-transient alignment where available within the verification budget.

### Behavioral verification

- Spoken count-in occurs before the first swing and again on Resume.
- Guided Swing and Metronome retain separate BPM memory.
- Saved BPM changes retain next-full-swing-boundary behavior.
- Rest, pause, resume, stop, haptics, and cycle-token alignment remain intact.
- No Guided Swing piano phrase, held oscillator, downswing sweep, or generated impact is audible.
- The exhale ends before the downswing.
- The downswing is digitally silent.
- Missing or invalid assets never trigger a synthetic fallback.

### Listening acceptance

Static checks cannot approve audio quality. Final acceptance requires listening on a physical iPhone speaker at low, medium, and high practical volume, plus a headphone check.

The phrase passes only if:

- the backswing unmistakably reads as a premium steel chain lift under increasing load;
- the ratchet remains mechanical and restrained rather than playful or metronomic;
- the exhale is slight, human, and clearly located at the top;
- the downswing is silent;
- the supplied WAV lands exactly at impact and remains recognizable as a real golf strike;
- every phase remains legible at 20, 60, and 75 BPM;
- repeated cycles do not become fatiguing.

## Risks

- Chain-lift recordings often contain theme-park ambience, squeals, voices, or long reverberation that cannot be cleanly removed.
- Repeating a short ratchet loop can create a cheap metronomic pattern unless loop seams and accents are controlled.
- A human exhale can feel gimmicky if it is too loud, intimate, or dramatic.
- The supplied WAV may contain pre-strike motion or tail that requires editing for exact impact alignment.
- iPhone speakers exaggerate ratchet transients and remove low mechanical body, so headphone-only mastering is insufficient.
- Licensing mistakes are a release risk; undocumented assets cannot ship.

## Done Conditions

The implementation is complete only when:

1. The external Premium Lift Hill audition is approved.
2. A documented, legally usable three-file production kit exists in the repo.
3. Live Guided Swing uses the sample-backed production renderer.
4. The rejected musical, procedural, zippy, and clown-like sounds are absent from live playback.
5. The downswing is silent and the supplied WAV's strike transient aligns with impact.
6. Timing and session invariants remain intact.
7. No synthetic fallback exists for missing Guided Swing assets.
8. Focused static verification passes.
9. Physical-iPhone listening approves the final source and master.
