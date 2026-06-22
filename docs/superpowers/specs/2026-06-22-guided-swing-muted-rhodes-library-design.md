# Guided Swing Muted Rhodes Library Design

**Date:** 2026-06-22

**Status:** Approved design awaiting implementation plan

**Scope:** Garage Tempo Builder, Guided Swing audio only

## Goal

Replace the current procedural Guided Swing rail with a premium, sample-backed Muted Rhodes phrase and establish a private audition library for evaluating future sound identities without turning Control Room into a novelty sound picker.

The delivered Guided Swing identity must feel warm, controlled, athletic, and suitable for repeated practice on an iPhone speaker. It must preserve the existing Tempo Builder timing and session behavior.

## Current System Observed

The live route is:

`GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`

`GarageTempoSessionController` owns count-in, rest, pause/resume, cycle boundaries, haptics, and pending BPM application. It passes a `GarageGuidedSwingCycleSchedule` into `ElasticSlingshotAudioEngine` for each Guided Swing cycle.

The live Guided Swing sound is still rendered procedurally inside `ElasticSlingshotAudioEngine`. The repo also contains a DEBUG-only sample preview lane that expects four WAV files, but the files are intentionally absent and the preview does not replace live Guided Swing.

The current procedural rail is rejected as the production direction because its sustained oscillator character sounds synthetic, cheap, and toy-like on a physical iPhone.

## Approved Product Direction

### Production identity

Guided Swing ships with one opinionated default identity: **Muted Rhodes**.

The phrase is:

1. A warm Rhodes cue at the start of the backswing.
2. A second overlapping cue one-third through the backswing.
3. A third overlapping cue two-thirds through the backswing.
4. A controlled fade to true silence before the top boundary.
5. Silence through the existing top hold and downswing transition.
6. One compact low Rhodes chord at the exact impact boundary.

The three backswing cues must read as one connected rising progression rather than three metronome ticks. The progression should gain harmonic weight and urgency without becoming bright, whimsical, cinematic, or electronic.

The impact chord must belong to the same Rhodes identity. It must be short, weighted, and immediately legible without sounding like a notification, game reward, drum hit, or exaggerated club collision.

### Player-facing library policy

The private audition library may contain multiple candidate kits, but the player-facing app ships only the approved signature identity. One alternate may be considered later only after listening proves that it serves a materially different training need.

The initial internal candidate order is:

1. Muted Rhodes
2. Felt Piano
3. Rosewood Marimba

Only Muted Rhodes is part of this implementation scope. Felt Piano and Rosewood Marimba are library slots for future sourcing and comparison, not implementation deliverables for this pass.

## Non-Goals

- Do not redesign the Tempo Builder screen or Guided Swing hero.
- Do not change navigation, persistence keys, BPM storage, or mode routing.
- Do not synchronize Guided Swing BPM with Metronome BPM.
- Do not change the spoken count-in, rest loop, pause/resume behavior, haptics, or pending-BPM boundary.
- Do not add a player-facing instrument browser or large sound library.
- Do not generate, synthesize, or procedurally substitute missing Rhodes assets.
- Do not alter Metronome sounds or behavior.
- Do not add third-party packages or runtime downloads.

## Audio Asset Contract

Each candidate kit uses four source files:

- `backswing_01.wav`
- `backswing_02.wav`
- `backswing_03.wav`
- `impact_confirm.wav`

Production assets must be:

- legally usable in a commercial app;
- recorded in the source manifest with source, author, URL, license, attribution requirements, edits, and phrase role;
- mono PCM WAV at 44.1 kHz or 48 kHz;
- dry, tightly trimmed, and free of baked-in reverb;
- mastered with conservative headroom and no clipped peaks;
- short enough that the render engine can guarantee silence at the top;
- accepted through physical-iPhone listening before being marked production-ready.

The three backswing files should use a restrained rising voicing in a warm mid-low register. They may overlap, but their combined energy must remain controlled. The impact file should be a compact lower chord with a fast, rounded decay.

The source manifest remains the authority for provenance and readiness. A candidate is unavailable unless every required file is present, decodable, and documented.

## Architecture

### Library model

Introduce a Guided Swing sample-kit model separate from the existing procedural profile metadata. A kit contains:

- a stable identifier;
- internal display and QA metadata;
- the four required asset names;
- readiness state derived from asset and manifest validation;
- production eligibility;
- mastering notes and intended role.

The production selection is opinionated in code. The internal DEBUG audition surface may select among complete candidate kits, but production does not expose that selection to the player.

### Asset loading

Guided Swing WAV files are loaded and decoded before playback begins. Decoded mono floating-point buffers are retained by the audio engine or a dedicated immutable sample library.

No file access, decoding, heap allocation, logging, string building, or lock-taking may be added to the audio render callback.

The loader must distinguish these states:

- ready;
- missing file;
- unreadable file;
- unsupported format;
- incomplete or invalid manifest.

DEBUG QA communicates the specific unavailable state. Production preparation fails safely if the required production kit is not ready.

### Render integration

`GarageGuidedSwingCycleSchedule` remains the timing authority.

For a backswing duration `topOffset`, cue starts are derived as:

- cue 1: `0.0 * topOffset`;
- cue 2: `1.0 / 3.0 * topOffset`;
- cue 3: `2.0 / 3.0 * topOffset`.

The renderer mixes overlapping sample voices from predecoded buffers. Each voice has only render-safe state: source buffer reference, current frame, gain, and fade state.

All active backswing voices enter a short de-click fade before `topOffset` and are guaranteed silent at `topOffset`. No sample energy plays during the established top hold or downswing interval. The impact sample begins at `impactOffset` and uses the existing cycle token and schedule so UI, haptics, and audio stay aligned.

The implementation must preserve one-cycle playback. That keeps existing count-in, rest, resume, and pending-BPM semantics under `GarageTempoSessionController` rather than introducing a second scheduler.

### Removal of the rejected rail

The live Guided Swing path must no longer call the procedural Guided Swing identity renderer when the production Rhodes kit is ready. Procedural rendering may remain only where required by Metronome or unrelated internal QA paths.

There is no automatic synthetic fallback for missing production Rhodes assets. Development failure must be visible rather than silently restoring the rejected sound.

## Audition Workflow

The internal QA surface uses the same sample loader, event timing, and render path intended for live Guided Swing. A preview that uses `AVAudioPlayer` scheduling alone is insufficient as final proof because it does not validate the production render integration.

The workflow is:

1. Add legally sourced WAVs and complete their manifest entries.
2. Validate file presence, decoding, channel count, sample rate, and manifest completeness.
3. Preview the kit through the production sample renderer at representative BPM values.
4. Compare on built-in iPhone speaker and headphones.
5. Adjust source edits and mastering outside the render callback.
6. Promote a kit to production eligibility only after physical-device acceptance.

The QA surface may expose candidate metadata and readiness. It must remain DEBUG-only and must not create production settings or persistence.

## Failure Handling

- A missing or invalid QA candidate remains disabled with a specific status.
- An incomplete manifest blocks candidate readiness even if files exist.
- A production kit that cannot prepare prevents Guided Swing audio from starting and exposes a development-visible failure state.
- The engine must not crash, partially play a phrase, or substitute an oscillator.
- Audio-session interruption and route-change behavior remain owned by the existing engine and session controller.
- If the output route changes, already decoded source buffers remain valid; any route-specific gain treatment must apply at a cycle boundary.

## Files Likely Involved

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/GarageGuidedSwingAudioProfile.swift`
- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPhrasePreview.swift`
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPreview_Audio/README.md`
- `LIFE-IN-SYNC/Garage/GuidedSwingInstrumentPreview_Audio/GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json`
- focused tests for asset readiness, timing, silence, and fallback policy

`GarageTempoSessionController.swift` and `HorizonVaultDialView.swift` should remain behaviorally unchanged unless implementation inspection proves a small integration change is required. Any broader session, persistence, route, or UI change requires separate approval.

## Verification and Acceptance

### Static verification

- Focused Swift parsing succeeds for every changed Swift file.
- `git diff --check` succeeds.
- Focused tests cover sample-kit readiness and timing math where available within the verification budget.

### Behavioral verification

- Spoken count-in occurs before the first swing and again on Resume.
- Guided Swing and Metronome retain separate BPM memory.
- Saved BPM changes retain the existing next-full-swing-boundary behavior.
- Rest, pause, resume, stop, preview, haptics, and cycle-token alignment remain intact.
- No Guided Swing click layer or procedural rail is audible.
- Top and downswing intervals are truly silent before impact.
- Missing or invalid sample assets never trigger a synthetic fallback.

### Listening acceptance

Static checks cannot approve audio quality. Final acceptance requires listening on a physical iPhone speaker at low, medium, and high practical volume, plus a headphone check.

The Muted Rhodes kit passes only if:

- the backswing reads as one connected build;
- every phase remains distinguishable at 20, 60, and 75 BPM;
- the top silence is obvious without feeling broken;
- impact is clear and weighted without being harsh;
- repeated cycles do not become fatiguing;
- no cue sounds like a toy, notification, fart-like oscillator, or generic game effect.

## Risks

- Poor source recordings cannot be repaired by runtime DSP without recreating the synthetic problem.
- Fixed sample tails may overlap poorly at the extremes of the BPM range; the implementation must fade safely rather than time-stretch aggressively.
- iPhone speakers can exaggerate upper-mid transients and remove low fundamentals, so headphone-only mastering is insufficient.
- A broad player-facing library would weaken the product identity; the audition library must remain internal.
- Licensing mistakes are a release risk; undocumented assets cannot ship.

## Done Conditions

The implementation is complete only when:

1. A documented, legally usable four-file Muted Rhodes kit exists in the repo.
2. Live Guided Swing uses the sample-backed production renderer.
3. The rejected procedural rail is absent from live Guided Swing playback.
4. Timing and session invariants remain intact.
5. No synthetic fallback exists for missing Guided Swing assets.
6. Internal QA can report kit readiness and preview through the production path.
7. Focused static verification passes.
8. Physical-iPhone listening approves the final source and master.
