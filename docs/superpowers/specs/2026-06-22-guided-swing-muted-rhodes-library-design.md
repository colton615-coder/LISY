# Guided Swing Signature Phrase Design

**Date:** 2026-06-22

**Status:** Option 1 approved; written spec awaiting review

**Scope:** Garage Tempo Builder, Guided Swing audio only

## Goal

Replace the rejected procedural and instrument-like Guided Swing phrases with one premium, elongated motion cue: a held backswing note, a short Tour Air downswing, and a dry Clean Face Strike at impact.

The result must feel serious, athletic, precise, and suitable for repeated practice on an iPhone speaker. It must preserve the existing Tempo Builder timing and session behavior.

## Current System Observed

The live route is:

`GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`

`GarageTempoSessionController` owns count-in, rest, pause/resume, cycle boundaries, haptics, and pending BPM application. It passes a `GarageGuidedSwingCycleSchedule` into `ElasticSlingshotAudioEngine` for each Guided Swing cycle.

The live Guided Swing sound is still rendered procedurally inside `ElasticSlingshotAudioEngine`. External listening prototypes have not changed the live app.

The following directions are rejected:

- sustained oscillator rails that sound synthetic or fart-like;
- piano or Rhodes phrasing;
- high-passed or pitched downswing effects that sound zippy;
- stacked stick, drum, hardwood, or metallic impacts that sound clown-like;
- cinematic crashes, notification-like transients, and novelty sounds.

## Approved Product Direction

Guided Swing ships with one opinionated signature phrase. It is not an instrument picker or sound-effects library.

### Backswing: held note

One continuous note begins with the backswing and remains present for the full backswing duration. It must:

- read as one sustained physical pressure cue rather than a piano note or repeated musical phrase;
- rise clearly in loudness toward the top without changing into a whistle or obvious pitch sweep;
- remain warm and controlled on the iPhone speaker;
- end cleanly at the top boundary without a click;
- leave the established top hold silent.

The existing approved held-note prototype remains the reference for this phase. This revision does not redesign it.

### Downswing: Tour Air

The downswing uses a completely new recorded source family. It begins only after the silent top hold and lasts for the existing downswing duration.

Tour Air must sound like a dense, close, aerodynamic club-speed rush. It must:

- have a low-mid body and broad air texture rather than a thin high-frequency hiss;
- accelerate through its amplitude and density envelope, not through a cartoon pitch rise;
- move directly into impact without a gap or pre-impact click;
- remain short, dry, and tightly controlled;
- avoid zipper, laser, whip-crack, cabasa, sci-fi, and white-noise character.

The source should be a real recorded club, rod, or comparably shaped object moving through air. A fabricated noise sweep is not an acceptable production substitute.

### Impact: Clean Face Strike

Impact uses a completely new recorded source family and begins at the exact impact boundary.

Clean Face Strike must sound like one close-miked, centered golf-ball strike. It must:

- have an immediate, dry face-contact transient;
- carry enough restrained low-mid body to survive an iPhone speaker;
- decay quickly without a drum note, metallic ring, wood knock, crash tail, or reverb;
- remain clean at practical high volume without clipping or harshness;
- read as athletic confirmation, not spectacle.

The preferred production source is an actual golf club striking a ball. If one recording cannot supply both articulation and body, a second real golf-impact recording may reinforce the body, but it must be time-aligned and mastered so the result still reads as one strike. Unrelated drum, stick, metal, or synthesized layers are prohibited.

## Timing Contract

`GarageGuidedSwingCycleSchedule` remains the timing authority.

For the default 60 BPM schedule:

- the held note begins at cycle time `0.0`;
- it follows the complete existing backswing interval;
- it fades to silence at `topOffset`;
- the existing top hold remains silent;
- Tour Air begins at `downswingOffset`;
- Clean Face Strike begins at `impactOffset`;
- the impact tail may continue only within the existing completion window.

All phase boundaries scale from the live schedule at other supported BPM values. Audio must not introduce a second scheduler or fixed timing table.

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

- `backswing_hold.wav`
- `downswing_tour_air.wav`
- `impact_clean_face.wav`

Production assets must be:

- legally usable in a commercial app;
- documented with source, author, URL, license, attribution requirements, edits, and phrase role;
- mono PCM WAV at 44.1 kHz or 48 kHz;
- dry, tightly trimmed, and free of baked-in reverb;
- mastered with conservative headroom and no clipped peaks;
- accepted through physical-iPhone listening before being marked production-ready.

The source manifest remains authoritative for provenance and readiness. The production phrase is unavailable unless every required file is present, decodable, and documented.

## Asset Loading and Render Integration

The assets are loaded and decoded before playback begins. Decoded mono floating-point buffers are retained by the audio engine or a dedicated immutable sample library.

No file access, decoding, heap allocation, logging, string building, or lock-taking may be added to the audio render callback.

The loader must distinguish ready, missing file, unreadable file, unsupported format, and invalid-manifest states. Development QA must show the specific unavailable state. Production must fail safely instead of restoring the rejected oscillator.

The renderer uses the existing one-cycle playback path and cycle token:

1. Scale or loop the held-note source with de-clicked boundaries so it covers the exact backswing duration.
2. Apply the approved rising gain envelope and guarantee silence at `topOffset`.
3. Preserve the existing silent top hold.
4. Fit Tour Air to the scheduled downswing with trim and envelope shaping; avoid aggressive pitch shifting or granular stretching.
5. Trigger Clean Face Strike natively at `impactOffset`; do not stretch it across the impact phase.

This keeps count-in, rest, resume, pending BPM, UI, haptics, and audio aligned under `GarageTempoSessionController`.

## Audition Workflow

Before live integration, create one external full-swing audition using the approved held note plus entirely new Tour Air and Clean Face Strike sources. Do not reuse layers from the rejected downswing or impact prototypes.

The audition must preserve the current 60 BPM phase timing so the user evaluates the actual motion contract. After approval:

1. document and add the final production sources;
2. validate file presence, decoding, channel count, sample rate, and manifest completeness;
3. preview through the production renderer at representative BPM values;
4. compare on built-in iPhone speaker and headphones;
5. promote the assets only after physical-device acceptance.

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

`GarageTempoSessionController.swift` and `HorizonVaultDialView.swift` should remain behaviorally unchanged unless implementation inspection proves a small integration change is required. Any broader session, persistence, route, or UI change requires separate approval.

## Verification and Acceptance

### Static verification

- Focused Swift parsing succeeds for every changed Swift file.
- `git diff --check` succeeds.
- Focused tests cover asset readiness and timing math where available within the verification budget.

### Behavioral verification

- Spoken count-in occurs before the first swing and again on Resume.
- Guided Swing and Metronome retain separate BPM memory.
- Saved BPM changes retain the existing next-full-swing-boundary behavior.
- Rest, pause, resume, stop, haptics, and cycle-token alignment remain intact.
- No Guided Swing click layer, piano phrase, or procedural rail is audible.
- The top hold is silent.
- Missing or invalid assets never trigger a synthetic fallback.

### Listening acceptance

Static checks cannot approve audio quality. Final acceptance requires listening on a physical iPhone speaker at low, medium, and high practical volume, plus a headphone check.

The signature phrase passes only if:

- the backswing reads as one held pressure build that becomes louder toward the top;
- Tour Air feels dense, fast, and aerodynamic without sounding zippy;
- Clean Face Strike sounds like one dry, centered golf strike without clown-like resonance;
- every phase remains distinguishable at 20, 60, and 75 BPM;
- repeated cycles do not become fatiguing;
- the full phrase feels serious, athletic, and precise.

## Risks

- A poor air recording will remain weak or artificial after processing; source quality is the primary control.
- Many golf-impact recordings include room echo, range ambience, or excessive metal ring and will not survive close repetition.
- iPhone speakers exaggerate upper-mid transients and remove low fundamentals, so headphone-only mastering is insufficient.
- Time-stretching the short downswing too aggressively can recreate the rejected zipper effect.
- Licensing mistakes are a release risk; undocumented assets cannot ship.

## Done Conditions

The implementation is complete only when:

1. The external Tour Air + Clean Face Strike audition is approved.
2. A documented, legally usable three-file production kit exists in the repo.
3. Live Guided Swing uses the sample-backed production renderer.
4. The rejected piano-like, zippy, clown-like, and procedural sounds are absent from live playback.
5. Timing and session invariants remain intact.
6. No synthetic fallback exists for missing Guided Swing assets.
7. Focused static verification passes.
8. Physical-iPhone listening approves the final source and master.
