# Guided Swing Audio Remodel

- Status: approved direction; Phase 2 profile scaffold implemented; sound implementation pending
- Scope: Garage Tempo Builder Guided Swing audio only
- Date: 2026-06-18
- Owner surface: live `GarageTempoBuilderView` flow
- Authority: source of truth for the Guided Swing audio identity remodel

## Authority And Boundaries

This document supersedes the Guided Swing sound-character language in:

- `docs/superpowers/specs/2026-06-08-tempo-builder-two-service-design.md`
- `docs/garage/GARAGE_REVAMP_BLUEPRINT.md`

Those documents remain authoritative for Tempo Builder routing, timing, persistence, UI hierarchy, and the separation between Guided Swing and Metronome. This remodel does not authorize navigation changes, persistence changes, a new audio package, or a broader UI redesign.

The names `Power Tour`, `Heavy Coil`, and `Whip Line` describe approved directional prototypes. No final bundled app assets with those profile names were found during this documentation pass. Existing Garage WAV files are current implementation material, not proof that the remodeled profiles are finished or accepted.

## Verdict

Guided Swing needs a full audio identity remodel, not a volume tweak.

The current direction was rejected because it sounds weak, thin, synthetic, and unpolished. Raising output gain on the same sound design would preserve the underlying problem and increase the risk of clipping. The next implementation must rebuild the full motion grammar around power, physicality, separation, and a premium impact.

## Current System Observed

- The live route is `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()` in `HorizonVaultDialView.swift`.
- `GarageTempoSessionController.swift` owns Guided Swing count-in, cycle scheduling, rest, haptics, and boundary-safe BPM application.
- `ElasticSlingshotAudioEngine.swift` owns the native real-time render path, phase rendering, local sample loading, output-route handling, and limiting.
- The engine already distinguishes build, top, downswing, impact, and tail phases.
- Existing Guided Swing profile cases are `tourWhip`, `heavySteel`, `glassLine`, `airCut`, `digitalVector`, and `rangeWood`, but they currently resolve to the same Tour Whip event plan. The live listening order exposes only `tourWhip`.
- Bundled Garage audio includes generated Guided Swing identity files and metronome samples under `LIFE-IN-SYNC/Garage/Metronome_Audio/`. These files may be evaluated or replaced later; this document does not approve them as final remodel assets.
- Guided Swing and Metronome share engine infrastructure but remain separate products. Guided Swing must not inherit Metronome's steady-click behavior.

## Rejected Direction

The remodel must not repeat any of the following:

- soft, breathy, meditation-style cues
- thin synthetic sketch sounds
- weak impact markers
- disconnected beeps
- generic Metronome behavior pretending to be a swing coach
- harsh clipping or audio slammed to 0 dB
- long, muddy tails
- anything cheap, toy-like, arbitrary, novelty-driven, or detached from golf motion

The rejected direction is a sound-design failure, not merely a loudness failure.

## Approved Direction

Guided Swing should be:

- loud
- powerful
- polished
- stereo-feeling
- sport-tech
- premium
- impact-forward
- golf-motion aware

The full swing must communicate one connected athletic sequence:

`pressure -> coil -> top lock -> release -> strike`

"Stereo-feeling" means width, separation, and motion that remain coherent when collapsed to an iPhone speaker. It does not justify phase tricks that disappear in mono, exaggerated panning, or headphone-only detail.

Power Tour, Heavy Coil, and Whip Line are the directional baseline. Future sounds should be judged as complete swings, not approved from isolated cue previews alone.

## Sound Model

Guided Swing is layered audio, not one stretched sound. Each layer has a distinct job and must align with the existing Guided Swing cycle schedule.

### Address Cue

A short, clear readiness marker. It should establish attention without sounding like a Metronome tick, meditation bell, or decorative notification.

### Backswing Pressure Build

A continuous rise in pressure, weight, and tension. It should follow the longer backswing motion and make the player feel load accumulating rather than hearing a static tone get louder.

### Top Checkpoint / Lock Marker

A compact, controlled transition marker at the top. It should communicate set and readiness to release without becoming a disconnected beep or creating a muddy pause.

### Downswing Release / Whoosh

A faster, more athletic release layer. It must contrast clearly with the backswing build and accelerate into impact rather than sounding like the build played in reverse.

### Impact Strike

The physical focal point. It must be short, dry, immediate, satisfying, and strong on an iPhone speaker. The strike should feel earned by the preceding motion rather than pasted onto the end.

### Optional Finish Tail

A brief finish layer may reinforce completion and polish. It is optional and must never mask impact, spill into the rest interval, or become a long cinematic wash.

## Initial Profile System

All three profiles use the same phase and timing contract. They differ through weight, transient shape, spectral balance, motion, and mastering—not through arbitrary timing changes or novelty effects.

### Power Tour

- Default profile.
- Balanced, powerful, and polished.
- Strong pressure build.
- Satisfying physical impact.
- Premium training feel with the broadest player usefulness.

### Heavy Coil

- Lower, heavier, and more grounded.
- Intended to help players who rush.
- Emphasizes pressure, load, body coil, and patience into the top.
- Release still accelerates decisively; heavy must not mean slow, muddy, or dull.

### Whip Line

- Sharper, faster, and more athletic.
- Emphasizes sequence, speed, release, and snap.
- Energetic without becoming sci-fi noise, a laser effect, or a brittle synthetic sketch.

## Audio Quality Rules

- Preserve mastering headroom throughout the signal chain.
- Do not clip.
- Achieve loud perceived volume through sound selection, gain staging, dynamics control, compression, transient shaping, and limiting—not raw peak abuse.
- Impact must be short, dry, physical, and satisfying.
- The build must rise with motion and tension, not only amplitude.
- The release must feel faster than the backswing.
- Address, top, and other cue layers must stay subordinate to the impact hierarchy.
- Prevent muddy overlap between the top marker, release, and impact.
- Optional tails must decay quickly and leave the rest interval clean.
- Each profile must remain intelligible and powerful at normal device volume.
- Validate on a physical iPhone speaker. Headphones, Mac speakers, waveforms, and meters are not sufficient acceptance evidence.
- Validate both complete-swing playback and repeated-session listening fatigue.
- Preserve local-first, offline playback and use native Apple audio frameworks only.

## Contracts To Preserve

- Guided Swing and Metronome keep separate saved BPM values.
- Guided Swing keeps its current count-in and full-cycle scheduling behavior unless a separately approved plan changes it.
- Running BPM edits continue to apply at the next full swing boundary.
- The existing Guided Swing phase schedule remains the timing authority.
- Metronome remains a direct, steady click trainer and receives no swing-build layers.
- Stop, interruption, rest, haptic, and Swing Capture coexistence behavior must not regress.
- The main screen remains focused on mode, BPM, Start/Stop, rhythm visual, and Control Room access.
- Profile work must not create major UI scope creep.

## Implementation Plan

### Phase 1: Audit The Live Audio Path

- Reconfirm the live Tempo Builder route before editing.
- Trace where Guided Swing count-in, build, top, release, impact, tail, output gain, and limiting are generated or loaded.
- Inventory existing bundled assets, licenses, render-path constraints, and route-specific behavior.
- Record which current identifiers and persistence values require compatibility handling.

Primary inspection targets:

- `LIFE-IN-SYNC/Garage/GarageTempoSessionController.swift`
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- `LIFE-IN-SYNC/Garage/GarageTempoAudioQAView.swift`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/`

### Phase 2: Introduce The Profile Contract

Scaffold status as of 2026-06-18:

- `LIFE-IN-SYNC/Garage/GarageGuidedSwingAudioProfile.swift` defines the layered profile contract.
- Power Tour, Heavy Coil, and Whip Line are represented as non-final scaffold profiles.
- Runtime sound generation and final mastered assets remain unimplemented and unaccepted.

- Add a Garage-local Guided Swing profile model for Power Tour, Heavy Coil, and Whip Line.
- Define each profile as a coordinated set of phase layers and mastering parameters.
- Make Power Tour the default while preserving or explicitly migrating the existing `garage.tempoBuilder.guidedSound` value.
- Keep this phase UI-neutral.

Any persistence migration or behavior change must be reviewed before implementation.

### Phase 3: Build Native Placeholder Profiles

- Implement placeholder/generated profile layers using native Apple audio only.
- Keep render-critical work allocation-free and free of logging or string construction.
- Shape each complete swing as a coordinated event rather than a collection of isolated beeps.
- Preserve headroom before any final dynamics or limiting stage.
- Treat placeholders as tuning material, not final approved assets.

### Phase 4: Wire Profile Selection Conservatively

- Wire profile selection only if the current Control Room already supports it or a minimal safe hook exists.
- Do not add profile controls to the main Guided Swing screen.
- If the safe UI hook is not ready, keep profiles hidden as implementation presets for listening QA.
- Do not expand Metronome controls or behavior as part of this phase.

### Phase 5: Run Physical-Device Audio QA

- Add an iPhone speaker QA checklist and capture the device model, iOS version, app volume, route, BPM, and profile tested.
- Test all three profiles as complete swings at low, middle, and high supported Guided Swing BPM values.
- Check impact authority, phase separation, repeated-loop fatigue, distortion, interruptions, Stop behavior, rest silence, and output-route changes.
- Use headphones as a secondary check only.
- Do not call the remodel complete until physical-device listening has passed human signoff.

## Acceptance Criteria

The remodel is successful only when:

- Full-swing audio feels intentional and powerful.
- Impact feels premium and physical.
- Backswing and downswing have clearly different energy.
- A listener can distinguish Power Tour, Heavy Coil, and Whip Line from complete swings.
- Nothing sounds like a cheap beep loop.
- There is no clipping, harsh distortion, or slammed peak behavior.
- Phase transitions remain clean, with no major masking or muddy overlap.
- The result holds up on a physical iPhone speaker.
- Existing timing, boundary application, rest, interruption, and Metronome behavior do not regress.
- There is no major UI scope creep.

## Open Decisions For Human Signoff

- [ ] Choose the favorite full-swing profile baseline.
- [ ] Choose the impact style.
- [ ] Choose how aggressive the pressure build should be.
- [ ] Decide whether profiles are hidden v1 presets or visible Control Room controls.
- [ ] Decide whether final sounds are synthesized in code or exported as bundled WAV assets.

## Done Condition For The Next Implementation Pass

The next pass is ready to begin when the open decisions needed for Phase 2 are resolved, the existing persistence compatibility is understood, and the team agrees that physical iPhone speaker listening—not code completion alone—is the final audio acceptance gate.
